const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { DatabaseSync } = require('node:sqlite');
const { mkdtempSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { after, before, test } = require('node:test');

const directory = mkdtempSync(join(tmpdir(), 'savor-api-'));
const databasePath = join(directory, 'test.sqlite');
const adminKey = 'local-test-operator-key';
let server;
let baseUrl;
let authToken;
let otherAuthToken;

before(async () => {
  server = spawn(process.execPath, [join(__dirname, '..', 'server.js')], {
    env: {
      ...process.env,
      PORT: '0',
      DATABASE_PATH: databasePath,
      API_ADMIN_KEY: adminKey,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('API server did not start.')), 10_000);
    server.stdout.on('data', (chunk) => {
      output += chunk.toString();
      const match = output.match(/http:\/\/localhost:(\d+)/);
      if (match) {
        clearTimeout(timeout);
        baseUrl = match[0];
        resolve();
      }
    });
    server.stderr.on('data', (chunk) => {
      output += chunk.toString();
    });
    server.once('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });
    server.once('exit', (code) => {
      clearTimeout(timeout);
      reject(new Error(`API server exited before starting (${code}): ${output}`));
    });
  });
});

after(async () => {
  if (server && server.exitCode === null) {
    await new Promise((resolve) => {
      server.once('exit', resolve);
      server.kill();
    });
  }
  rmSync(directory, { recursive: true, force: true });
});

test('restaurant and menu endpoints return the seeded catalog', async () => {
  const health = await fetch(`${baseUrl}/api/health`);
  assert.deepEqual(await health.json(), { status: 'ok', database: 'sqlite' });

  const restaurantsResponse = await fetch(`${baseUrl}/api/restaurants`);
  assert.equal(restaurantsResponse.status, 200);
  const restaurants = await restaurantsResponse.json();
  assert.equal(restaurants.length, 12);
  assert.equal(restaurants[0].isFeatured, true);

  const dishSearch = await fetch(`${baseUrl}/api/restaurants?search=kottu`);
  assert.equal((await dishSearch.json())[0].name, 'Curry Leaf');

  const menuResponse = await fetch(`${baseUrl}/api/restaurants/5/menu`);
  const menu = await menuResponse.json();
  assert.equal(menuResponse.status, 200);
  assert.equal(menu[0].restaurantId, 5);
  assert.equal(menu[0].isPopular, true);

  const db = new DatabaseSync(databasePath, { readOnly: true });
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM restaurants').get().count, 12);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM menu_items').get().count, 26);
  db.close();
});

test('registration, login, saved addresses and session logout use the API', async () => {
  const register = (name, email) => fetch(`${baseUrl}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, email, password: 'correct-horse-72' }),
  });
  const response = await register('Savor Guest', 'guest@example.com');
  assert.equal(response.status, 201);
  const session = await response.json();
  authToken = session.token;
  assert.equal(session.user.email, 'guest@example.com');
  assert.ok(!JSON.stringify(session).includes('password'));

  const duplicate = await register('Another Guest', 'GUEST@example.com');
  assert.equal(duplicate.status, 409);

  const login = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'GUEST@example.com',
      password: 'correct-horse-72',
    }),
  });
  assert.equal(login.status, 200);
  assert.equal((await login.json()).user.id, session.user.id);

  const badLogin = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'guest@example.com', password: 'incorrect-password' }),
  });
  assert.equal(badLogin.status, 401);

  const secondUser = await register('Other Guest', 'other@example.com');
  assert.equal(secondUser.status, 201);
  otherAuthToken = (await secondUser.json()).token;

  const addresses = await fetch(`${baseUrl}/api/addresses`, {
    headers: { Authorization: `Bearer ${authToken}` },
  });
  assert.equal(addresses.status, 200);
  const savedAddresses = await addresses.json();
  assert.equal(savedAddresses[0].address, 'Colombo 07');
  assert.equal(savedAddresses[0].isDefault, true);

  const addedAddress = await fetch(`${baseUrl}/api/addresses`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify({
      label: 'Work',
      address: '40 Galle Road, Colombo 03',
      isDefault: true,
    }),
  });
  assert.equal(addedAddress.status, 201);
  assert.equal((await addedAddress.json()).isDefault, true);

  const updatedAddresses = await fetch(`${baseUrl}/api/addresses`, {
    headers: { Authorization: `Bearer ${authToken}` },
  });
  const updatedAddressList = await updatedAddresses.json();
  assert.deepEqual(
    updatedAddressList.map((address) => address.isDefault),
    [true, false],
  );

  const workAddress = updatedAddressList.find((address) => address.label === 'Work');
  const editedAddress = await fetch(
    `${baseUrl}/api/addresses/${workAddress.id}`,
    {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        label: 'Studio',
        address: '40 Galle Road, Colombo 03, Sri Lanka',
      }),
    },
  );
  assert.equal(editedAddress.status, 200);
  assert.equal((await editedAddress.json()).label, 'Studio');

  const homeAddress = (await (await fetch(`${baseUrl}/api/addresses`, {
    headers: { Authorization: `Bearer ${authToken}` },
  })).json()).find((address) => address.label === 'Home');
  const defaultAddress = await fetch(
    `${baseUrl}/api/addresses/${homeAddress.id}/default`,
    {
      method: 'PUT',
      headers: { Authorization: `Bearer ${authToken}` },
    },
  );
  assert.equal(defaultAddress.status, 200);
});

test('card authorization returns both success and decline outcomes', async () => {
  const authorize = (lastFour) => fetch(`${baseUrl}/api/payments/authorize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify({
      method: 'card',
      lastFour,
      items: [{ menuItemId: 501, quantity: 2 }],
    }),
  });
  const approved = await authorize('4242');
  assert.equal(approved.status, 201);
  const payment = await approved.json();
  assert.equal(payment.status, 'authorized');
  assert.equal(payment.amount, 2700);

  const declined = await authorize('0002');
  assert.equal(declined.status, 402);
  assert.equal((await declined.json()).status, 'failed');
});

test('order creation validates items and persists server-calculated totals', async () => {
  const response = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify({
      address: '12 Flower Road, Colombo 07',
      paymentMethod: 'cash',
      items: [{ menuItemId: 501, quantity: 2 }],
    }),
  });
  const order = await response.json();
  assert.equal(response.status, 201);
  assert.equal(order.total, 2700);
  assert.equal(order.itemCount, 2);
  assert.equal(order.status, 'Confirmed');
  assert.equal(order.paymentMethod, 'cash');
  assert.equal(order.paymentStatus, 'pending');

  const stored = await fetch(`${baseUrl}/api/orders/${order.id}`, {
    headers: { Authorization: `Bearer ${authToken}` },
  });
  assert.deepEqual(await stored.json(), order);

  const privateOrder = await fetch(`${baseUrl}/api/orders/${order.id}`, {
    headers: { Authorization: `Bearer ${otherAuthToken}` },
  });
  assert.equal(privateOrder.status, 404);

  const authorizationResponse = await fetch(`${baseUrl}/api/payments/authorize`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify({
      method: 'card',
      lastFour: '4242',
      items: [{ menuItemId: 501, quantity: 1 }],
    }),
  });
  const payment = await authorizationResponse.json();
  const cardOrderResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify({
      address: '12 Flower Road, Colombo 07',
      paymentMethod: 'card',
      paymentId: payment.paymentId,
      items: [{ menuItemId: 501, quantity: 1 }],
    }),
  });
  const cardOrder = await cardOrderResponse.json();
  assert.equal(cardOrderResponse.status, 201);
  assert.equal(cardOrder.paymentStatus, 'paid');
  assert.equal(cardOrder.paymentMethod, 'card');
  const reusedPayment = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify({
      address: '12 Flower Road, Colombo 07',
      paymentMethod: 'card',
      paymentId: payment.paymentId,
      items: [{ menuItemId: 501, quantity: 1 }],
    }),
  });
  assert.equal(reusedPayment.status, 402);

  const advanced = await fetch(`${baseUrl}/api/orders/${order.id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-Admin-Key': adminKey,
    },
    body: JSON.stringify({ status: 'Preparing' }),
  });
  assert.equal((await advanced.json()).status, 'Preparing');
  const skipped = await fetch(`${baseUrl}/api/orders/${order.id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-Admin-Key': adminKey,
    },
    body: JSON.stringify({ status: 'Delivered' }),
  });
  assert.equal(skipped.status, 409);
  const history = await fetch(`${baseUrl}/api/orders`, {
    headers: { Authorization: `Bearer ${authToken}` },
  });
  assert.equal((await history.json()).length, 2);
});

test('order creation rejects invalid and cross-restaurant orders', async () => {
  const send = (body) => fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify(body),
  });

  const badAddress = await send({
    address: 'No',
    items: [{ menuItemId: 501, quantity: 1 }],
  });
  assert.equal(badAddress.status, 400);

  const mixedRestaurants = await send({
    address: '12 Flower Road, Colombo 07',
    items: [
      { menuItemId: 501, quantity: 1 },
      { menuItemId: 201, quantity: 1 },
    ],
  });
  assert.equal(mixedRestaurants.status, 400);

  const overQuantity = await send({
    address: '12 Flower Road, Colombo 07',
    items: [
      { menuItemId: 501, quantity: 99 },
      { menuItemId: 501, quantity: 1 },
    ],
  });
  assert.equal(overQuantity.status, 400);

  const invalidJson = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: '{',
  });
  assert.equal(invalidJson.status, 400);

  const unauthenticated = await fetch(`${baseUrl}/api/orders`);
  assert.equal(unauthenticated.status, 401);

  const loggedOut = await fetch(`${baseUrl}/api/auth/logout`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${otherAuthToken}` },
  });
  assert.equal(loggedOut.status, 200);
  const expiredSession = await fetch(`${baseUrl}/api/auth/me`, {
    headers: { Authorization: `Bearer ${otherAuthToken}` },
  });
  assert.equal(expiredSession.status, 401);

  const unauthorizedStatusUpdate = await fetch(`${baseUrl}/api/orders/1`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify({ status: 'Preparing' }),
  });
  assert.equal(unauthorizedStatusUpdate.status, 403);
});

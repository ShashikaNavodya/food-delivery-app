const { createServer } = require('node:http');
const { dirname, join } = require('node:path');
const { mkdirSync } = require('node:fs');
const { DatabaseSync } = require('node:sqlite');
const {
  createHash,
  randomBytes,
  scryptSync,
  timingSafeEqual,
} = require('node:crypto');

const port = Number(process.env.PORT || 4000);
const dataDirectory = join(__dirname, 'data');
const databasePath = process.env.DATABASE_PATH || join(dataDirectory, 'savor.sqlite');
mkdirSync(dirname(databasePath), { recursive: true });
const database = new DatabaseSync(databasePath);

database.exec(`
  PRAGMA foreign_keys = ON;
  CREATE TABLE IF NOT EXISTS restaurants (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    cuisine TEXT NOT NULL,
    image_url TEXT NOT NULL,
    rating REAL NOT NULL,
    delivery_minutes INTEGER NOT NULL,
    delivery_fee REAL NOT NULL,
    is_featured INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS menu_items (
    id INTEGER PRIMARY KEY,
    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT NOT NULL,
    price REAL NOT NULL CHECK (price >= 0),
    category TEXT NOT NULL,
    is_popular INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id),
    address TEXT NOT NULL,
    subtotal REAL NOT NULL,
    delivery_fee REAL NOT NULL,
    total REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'Confirmed',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL COLLATE NOCASE UNIQUE,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS delivery_addresses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    address TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount REAL NOT NULL,
    method TEXT NOT NULL,
    last_four TEXT,
    status TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id INTEGER NOT NULL REFERENCES menu_items(id),
    name TEXT NOT NULL,
    price REAL NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0)
  );
`);

const existingOrderColumns = new Set(
  database.prepare('PRAGMA table_info(orders)').all().map((column) => column.name),
);
for (const [name, definition] of [
  ['user_id', 'INTEGER REFERENCES users(id)'],
  ['payment_id', 'INTEGER REFERENCES payments(id)'],
  ['payment_method', "TEXT NOT NULL DEFAULT 'cash'"],
  ['payment_status', "TEXT NOT NULL DEFAULT 'pending'"],
]) {
  if (!existingOrderColumns.has(name)) {
    database.exec(`ALTER TABLE orders ADD COLUMN ${name} ${definition}`);
  }
}

const restaurants = [
  [1, 'Olive & Thyme', 'Mediterranean · Healthy', 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1000&q=85', 4.9, 25, 350, 1],
  [2, 'Bun & Co.', 'Burgers · American', 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1000&q=85', 4.8, 20, 250, 1],
  [3, 'Little Napoli', 'Pizza · Italian', 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=1000&q=85', 4.7, 30, 300, 0],
  [4, 'Nori House', 'Japanese · Sushi', 'https://images.unsplash.com/photo-1579027989536-b7b1f875659b?w=1000&q=85', 4.9, 35, 400, 0],
  [5, 'Curry Leaf', 'Sri Lankan · Local', 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=1000&q=85', 4.8, 28, 200, 0],
  [6, 'Taco Haven', 'Mexican · Tacos', 'https://images.unsplash.com/photo-1551508766-5b8f6b4a0f73?w=1000&q=85', 4.7, 24, 275, 1],
  [7, 'Green Leaf', 'Plant-based · Healthy', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1000&q=85', 4.8, 22, 225, 1],
  [8, 'Burger Joint', 'Burgers · American', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1000&q=85', 4.9, 28, 250, 1],
  [9, 'Sushi Garden', 'Japanese · Sushi', 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=1000&q=85', 4.6, 30, 300, 1],
  [10, 'Pasta Palace', 'Italian · Pasta', 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=1000&q=85', 4.7, 26, 275, 1],
  [11, 'Sweet Spot', 'Bakery · Desserts', 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=1000&q=85', 4.8, 20, 200, 0],
  [12, 'Colombo Fresh Market', 'Groceries · Fresh produce', 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=1000&q=85', 4.6, 35, 150, 0],
];

const menuItems = [
  [101, 1, 'Burrata Garden Bowl', 'Creamy burrata, heirloom tomatoes, basil & sourdough.', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=700&q=85', 1650, 'Popular', 1],
  [102, 1, 'Lemon Herb Salmon', 'Wild salmon, herbed couscous & charred lemon.', 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=700&q=85', 2100, 'Mains', 1],
  [103, 1, 'Roasted Pumpkin Hummus', 'Silky pumpkin hummus, toasted seeds & warm pita.', 'https://images.unsplash.com/photo-1577906096429-f73c2c312435?w=700&q=85', 1100, 'Starters', 0],
  [201, 2, 'The Classic Smash', 'Double smashed patty, sharp cheddar, pickles & house sauce.', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=700&q=85', 1400, 'Popular', 1],
  [202, 2, 'Truffle Parmesan Fries', 'Golden fries, shaved parmesan & truffle aioli.', 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=700&q=85', 850, 'Sides', 1],
  [203, 2, 'Crispy Chicken Burger', 'Buttermilk fried chicken, slaw & hot honey.', 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=700&q=85', 1350, 'Mains', 0],
  [301, 3, 'Margherita D.O.P.', 'San Marzano tomato, fior di latte & fresh basil.', 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=700&q=85', 1500, 'Popular', 1],
  [302, 3, 'Spicy Salami', 'Calabrian chilli, fennel salami & hot honey.', 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=700&q=85', 1800, 'Mains', 1],
  [401, 4, 'Salmon Avocado Roll', 'Eight pieces, fresh salmon, ripe avocado & sesame.', 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=700&q=85', 1750, 'Popular', 1],
  [402, 4, 'Crispy Prawn Tempura', 'Tiger prawns, light tempura & tangy ponzu dip.', 'https://images.unsplash.com/photo-1553621042-f6e147245754?w=700&q=85', 1900, 'Mains', 0],
  [501, 5, 'Creamy Chicken Kottu', 'Chopped roti, spiced chicken & a creamy curry sauce.', 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=700&q=85', 1250, 'Popular', 1],
  [502, 5, 'Devilled Prawns', 'Wok-tossed prawns with sweet chilli and roasted peppers.', 'https://images.unsplash.com/photo-1625944525533-473f1a3d54e7?w=700&q=85', 1600, 'Mains', 1],
  [601, 6, 'Baja Fish Tacos', 'Crispy market fish, lime slaw and smoky chipotle crema.', 'https://images.unsplash.com/photo-1551508766-5b8f6b4a0f73?w=700&q=85', 1450, 'Popular', 1],
  [602, 6, 'Loaded Chicken Nachos', 'Corn tortilla chips, grilled chicken, pico de gallo and queso.', 'https://images.unsplash.com/photo-1513456852971-30c0b8199d4d?w=700&q=85', 1250, 'Mains', 1],
  [701, 7, 'Rainbow Nourish Bowl', 'Avocado, roasted chickpeas, greens and tahini dressing.', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=700&q=85', 1350, 'Popular', 1],
  [702, 7, 'Crispy Cauliflower Wrap', 'Spiced cauliflower, crunchy slaw and herby yoghurt.', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=700&q=85', 1050, 'Mains', 0],
  [801, 8, 'The Double Joint', 'Two smashed beef patties, cheddar, pickles and house sauce.', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=700&q=85', 1550, 'Popular', 1],
  [802, 8, 'Crispy Chicken Stack', 'Crunchy chicken, lettuce, tomato and pepper mayo.', 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=700&q=85', 1350, 'Mains', 1],
  [901, 9, 'Garden Salmon Roll', 'Fresh salmon, avocado and cucumber, eight pieces.', 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=700&q=85', 1650, 'Popular', 1],
  [902, 9, 'Crispy Prawn Maki', 'Tempura prawn, sesame and a sweet chilli glaze.', 'https://images.unsplash.com/photo-1553621042-f6e147245754?w=700&q=85', 1500, 'Mains', 1],
  [1001, 10, 'Creamy Tuscan Penne', 'Penne with sun-dried tomato, parmesan and basil.', 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=700&q=85', 1450, 'Popular', 1],
  [1002, 10, 'Classic Beef Lasagna', 'Slow-cooked beef ragu, pasta sheets and golden bechamel.', 'https://images.unsplash.com/photo-1574894709920-11b28e7367e3?w=700&q=85', 1750, 'Mains', 1],
  [1101, 11, 'Strawberry Cream Cake', 'Soft vanilla sponge, fresh strawberries and whipped cream.', 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=700&q=85', 950, 'Popular', 1],
  [1102, 11, 'Chocolate Fudge Brownie', 'Warm chocolate brownie with toasted hazelnuts.', 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=700&q=85', 650, 'Desserts', 1],
  [1201, 12, 'Fresh Fruit Box', 'A seasonal selection of fresh local fruit.', 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=700&q=85', 1200, 'Produce', 1],
  [1202, 12, 'Market Greens Bundle', 'Fresh leafy greens and herbs for your kitchen.', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=700&q=85', 750, 'Produce', 0],
];

const insertRestaurant = database.prepare(`
  INSERT OR IGNORE INTO restaurants
    (id, name, cuisine, image_url, rating, delivery_minutes, delivery_fee, is_featured)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?)
`);
const insertMenuItem = database.prepare(`
  INSERT OR IGNORE INTO menu_items
    (id, restaurant_id, name, description, image_url, price, category, is_popular)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?)
`);
database.exec('BEGIN IMMEDIATE');
try {
  for (const restaurant of restaurants) insertRestaurant.run(...restaurant);
  for (const item of menuItems) insertMenuItem.run(...item);
  database.exec('COMMIT');
} catch (error) {
  database.exec('ROLLBACK');
  throw error;
}

const restaurantSelect = `
  SELECT id, name, cuisine, image_url AS imageUrl, rating,
         delivery_minutes AS deliveryMinutes, delivery_fee AS deliveryFee,
         is_featured AS isFeatured
  FROM restaurants
`;
const menuSelect = `
  SELECT id, restaurant_id AS restaurantId, name, description,
         image_url AS imageUrl, price, category, is_popular AS isPopular
  FROM menu_items
`;

function withTransaction(work) {
  database.exec('BEGIN IMMEDIATE');
  try {
    const result = work();
    database.exec('COMMIT');
    return result;
  } catch (error) {
    database.exec('ROLLBACK');
    throw error;
  }
}

function send(response, status, body) {
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Admin-Key',
  });
  response.end(JSON.stringify(body));
}

async function readJson(request) {
  let body = '';
  for await (const chunk of request) {
    body += chunk;
    if (body.length > 1_000_000) {
      throw new HttpError(413, 'Request body is too large.');
    }
  }
  try {
    return JSON.parse(body);
  } catch {
    throw new HttpError(400, 'Request body must be valid JSON.');
  }
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function getOrder(id) {
  const order = database.prepare(`
    SELECT orders.id, restaurants.name AS restaurantName, orders.total,
           orders.status, orders.created_at AS createdAt,
           orders.payment_method AS paymentMethod,
           orders.payment_status AS paymentStatus,
           COALESCE(SUM(order_items.quantity), 0) AS itemCount
    FROM orders
    JOIN restaurants ON restaurants.id = orders.restaurant_id
    LEFT JOIN order_items ON order_items.order_id = orders.id
    WHERE orders.id = ?
    GROUP BY orders.id
  `).get(id);
  if (!order) return null;
  order.itemCount = Number(order.itemCount);
  return order;
}

function tokenDigest(token) {
  return createHash('sha256').update(token).digest('hex');
}

function issueSession(userId) {
  const token = randomBytes(32).toString('base64url');
  database.prepare(`
    INSERT INTO sessions (token_hash, user_id, expires_at)
    VALUES (?, ?, datetime('now', '+30 days'))
  `).run(tokenDigest(token), userId);
  return token;
}

function publicUser(user) {
  return { id: user.id, name: user.name, email: user.email };
}

function authenticate(request) {
  const authorization = request.headers.authorization || '';
  const match = authorization.match(/^Bearer ([A-Za-z0-9_-]{32,})$/);
  if (!match) throw new HttpError(401, 'Sign in to continue.');
  const user = database.prepare(`
    SELECT users.id, users.name, users.email
    FROM sessions
    JOIN users ON users.id = sessions.user_id
    WHERE sessions.token_hash = ? AND sessions.expires_at > datetime('now')
  `).get(tokenDigest(match[1]));
  if (!user) throw new HttpError(401, 'Your session has expired. Please sign in again.');
  return user;
}

function requireObject(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw new HttpError(400, 'Request body must be a JSON object.');
  }
}

function normalizeEmail(value) {
  if (typeof value !== 'string') return '';
  return value.trim().toLowerCase();
}

function createAccountSession(user) {
  const token = issueSession(user.id);
  return { token, user: publicUser(user) };
}

function resolveItems(input) {
  if (!Array.isArray(input) || input.length < 1 || input.length > 50) {
    throw new HttpError(400, 'An order must include between 1 and 50 menu items.');
  }
  const quantities = new Map();
  for (const item of input) {
    if (item === null || typeof item !== 'object' || Array.isArray(item)) {
      throw new HttpError(400, 'Each order item must be an object.');
    }
    const id = Number(item.menuItemId);
    const quantity = Number(item.quantity);
    if (!Number.isSafeInteger(id) || !Number.isSafeInteger(quantity) || quantity < 1 || quantity > 99) {
      throw new HttpError(400, 'Each item must have a valid menu item ID and quantity (1–99).');
    }
    const totalQuantity = (quantities.get(id) || 0) + quantity;
    if (totalQuantity > 99) {
      throw new HttpError(400, 'The quantity for each menu item cannot exceed 99.');
    }
    quantities.set(id, totalQuantity);
  }
  const ids = [...quantities.keys()];
  const placeholders = ids.map(() => '?').join(',');
  const items = database.prepare(`
    SELECT id, restaurant_id AS restaurantId, name, price
    FROM menu_items WHERE id IN (${placeholders})
  `).all(...ids);
  if (items.length !== ids.length) {
    throw new HttpError(400, 'One or more menu items are unavailable.');
  }
  const restaurantId = items[0].restaurantId;
  if (items.some((item) => item.restaurantId !== restaurantId)) {
    throw new HttpError(400, 'All items in an order must come from the same restaurant.');
  }
  const restaurant = database.prepare(
    'SELECT delivery_fee AS deliveryFee FROM restaurants WHERE id = ?',
  ).get(restaurantId);
  const subtotal = items.reduce((sum, item) => sum + item.price * quantities.get(item.id), 0);
  return {
    items,
    quantities,
    restaurantId,
    subtotal,
    deliveryFee: restaurant.deliveryFee,
    total: subtotal + restaurant.deliveryFee,
  };
}

async function handle(request, response) {
  if (request.method === 'OPTIONS') return send(response, 204, {});
  const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);
  const route = url.pathname.replace(/\/+$/, '') || '/';

  if (request.method === 'GET' && route === '/api/health') {
    return send(response, 200, { status: 'ok', database: 'sqlite' });
  }

  if (request.method === 'POST' && route === '/api/auth/register') {
    const body = await readJson(request);
    requireObject(body);
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    const email = normalizeEmail(body.email);
    const password = typeof body.password === 'string' ? body.password : '';
    if (name.length < 2 || name.length > 80) {
      throw new HttpError(400, 'Enter your name (2–80 characters).');
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
      throw new HttpError(400, 'Enter a valid email address.');
    }
    if (password.length < 8 || password.length > 128) {
      throw new HttpError(400, 'Your password must be between 8 and 128 characters.');
    }
    const salt = randomBytes(16).toString('hex');
    const passwordHash = scryptSync(password, salt, 64).toString('hex');
    let user;
    try {
      withTransaction(() => {
        const result = database.prepare(`
          INSERT INTO users (name, email, password_hash, password_salt)
          VALUES (?, ?, ?, ?)
        `).run(name, email, passwordHash, salt);
        user = database.prepare('SELECT id, name, email FROM users WHERE id = ?')
          .get(Number(result.lastInsertRowid));
        database.prepare(`
          INSERT INTO delivery_addresses (user_id, label, address, is_default)
          VALUES (?, 'Home', 'Colombo 07', 1)
        `).run(user.id);
      });
    } catch (error) {
      if (error.errcode === 2067) {
        throw new HttpError(409, 'An account with this email already exists.');
      }
      throw error;
    }
    return send(response, 201, createAccountSession(user));
  }

  if (request.method === 'POST' && route === '/api/auth/login') {
    const body = await readJson(request);
    requireObject(body);
    const email = normalizeEmail(body.email);
    const password = typeof body.password === 'string' ? body.password : '';
    if (password.length > 128) {
      throw new HttpError(401, 'Email or password is incorrect.');
    }
    const user = database.prepare(`
      SELECT id, name, email, password_hash AS passwordHash,
             password_salt AS passwordSalt
      FROM users WHERE email = ?
    `).get(email);
    const candidateHash = scryptSync(password, user?.passwordSalt || 'invalid-user-salt', 64);
    const storedHash = user ? Buffer.from(user.passwordHash, 'hex') : Buffer.alloc(64);
    if (!timingSafeEqual(candidateHash, storedHash)) {
      throw new HttpError(401, 'Email or password is incorrect.');
    }
    return send(response, 200, createAccountSession(user));
  }

  if (route.startsWith('/api/auth/')) {
    const user = authenticate(request);
    if (request.method === 'GET' && route === '/api/auth/me') {
      return send(response, 200, publicUser(user));
    }
    if (request.method === 'POST' && route === '/api/auth/logout') {
      const token = request.headers.authorization.slice('Bearer '.length);
      database.prepare('DELETE FROM sessions WHERE token_hash = ?').run(tokenDigest(token));
      return send(response, 200, { message: 'Signed out.' });
    }
  }

  if (route.startsWith('/api/addresses')) {
    const user = authenticate(request);
    if (request.method === 'GET' && route === '/api/addresses') {
      return send(response, 200, database.prepare(`
        SELECT id, label, address, is_default AS isDefault
        FROM delivery_addresses WHERE user_id = ?
        ORDER BY is_default DESC, id DESC
      `).all(user.id).map((address) => ({
        ...address,
        isDefault: Boolean(address.isDefault),
      })));
    }
    if (request.method === 'POST' && route === '/api/addresses') {
      const body = await readJson(request);
      requireObject(body);
      const address = typeof body.address === 'string' ? body.address.trim() : '';
      const label = typeof body.label === 'string' ? body.label.trim() : '';
      if (address.length < 5 || address.length > 300) {
        throw new HttpError(400, 'Enter a delivery address between 5 and 300 characters.');
      }
      if (label.length < 2 || label.length > 40) {
        throw new HttpError(400, 'Enter an address label between 2 and 40 characters.');
      }
      const makeDefault = body.isDefault === true;
      const insertAddress = () => {
        if (makeDefault) {
          database.prepare('UPDATE delivery_addresses SET is_default = 0 WHERE user_id = ?')
            .run(user.id);
        }
        const result = database.prepare(`
          INSERT INTO delivery_addresses (user_id, label, address, is_default)
          VALUES (?, ?, ?, ?)
        `).run(user.id, label, address, makeDefault ? 1 : 0);
        return database.prepare(`
          SELECT id, label, address, is_default AS isDefault
          FROM delivery_addresses WHERE id = ?
        `).get(Number(result.lastInsertRowid));
      };
      const saved = withTransaction(insertAddress);
      return send(response, 201, { ...saved, isDefault: Boolean(saved.isDefault) });
    }
    const editMatch = route.match(/^\/api\/addresses\/(\d+)$/);
    if (request.method === 'PATCH' && editMatch) {
      const body = await readJson(request);
      requireObject(body);
      const label = typeof body.label === 'string' ? body.label.trim() : '';
      const address = typeof body.address === 'string' ? body.address.trim() : '';
      if (label.length < 2 || label.length > 40) {
        throw new HttpError(400, 'Enter an address label between 2 and 40 characters.');
      }
      if (address.length < 5 || address.length > 300) {
        throw new HttpError(400, 'Enter a delivery address between 5 and 300 characters.');
      }
      const addressId = Number(editMatch[1]);
      const result = database.prepare(`
        UPDATE delivery_addresses SET label = ?, address = ?
        WHERE id = ? AND user_id = ?
      `).run(label, address, addressId, user.id);
      if (result.changes === 0) throw new HttpError(404, 'Delivery address not found.');
      const saved = database.prepare(`
        SELECT id, label, address, is_default AS isDefault
        FROM delivery_addresses WHERE id = ? AND user_id = ?
      `).get(addressId, user.id);
      return send(response, 200, { ...saved, isDefault: Boolean(saved.isDefault) });
    }
    const addressMatch = route.match(/^\/api\/addresses\/(\d+)\/default$/);
    if (request.method === 'PUT' && addressMatch) {
      const addressId = Number(addressMatch[1]);
      const found = database.prepare(
        'SELECT id FROM delivery_addresses WHERE id = ? AND user_id = ?',
      ).get(addressId, user.id);
      if (!found) throw new HttpError(404, 'Delivery address not found.');
      withTransaction(() => {
        database.prepare('UPDATE delivery_addresses SET is_default = 0 WHERE user_id = ?')
          .run(user.id);
        database.prepare('UPDATE delivery_addresses SET is_default = 1 WHERE id = ?')
          .run(addressId);
      });
      return send(response, 200, { message: 'Default delivery address updated.' });
    }
    const deleteMatch = route.match(/^\/api\/addresses\/(\d+)$/);
    if (request.method === 'DELETE' && deleteMatch) {
      const addressId = Number(deleteMatch[1]);
      const found = database.prepare(
        'SELECT id, is_default AS isDefault FROM delivery_addresses WHERE id = ? AND user_id = ?',
      ).get(addressId, user.id);
      if (!found) throw new HttpError(404, 'Delivery address not found.');
      if (found.isDefault) {
        throw new HttpError(409, 'Choose another default address before removing this one.');
      }
      database.prepare('DELETE FROM delivery_addresses WHERE id = ?').run(addressId);
      return send(response, 200, { message: 'Delivery address removed.' });
    }
  }

  if (request.method === 'GET' && route === '/api/restaurants') {
    const search = (url.searchParams.get('search') || '').trim();
    const statement = search
      ? database.prepare(`${restaurantSelect} WHERE name LIKE ? OR cuisine LIKE ? OR id IN (SELECT restaurant_id FROM menu_items WHERE name LIKE ? OR category LIKE ?) ORDER BY is_featured DESC, rating DESC`)
      : database.prepare(`${restaurantSelect} ORDER BY is_featured DESC, rating DESC`);
    const rows = search
      ? statement.all(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`)
      : statement.all();
    return send(response, 200, rows.map((row) => ({
      ...row,
      isFeatured: Boolean(row.isFeatured),
    })));
  }

  const menuMatch = route.match(/^\/api\/restaurants\/(\d+)\/menu$/);
  if (request.method === 'GET' && menuMatch) {
    const restaurantId = Number(menuMatch[1]);
    if (!database.prepare('SELECT id FROM restaurants WHERE id = ?').get(restaurantId)) {
      return send(response, 404, { error: 'Restaurant not found.' });
    }
    const rows = database.prepare(`${menuSelect} WHERE restaurant_id = ? ORDER BY is_popular DESC, id`).all(restaurantId);
    return send(response, 200, rows.map((row) => ({
      ...row,
      isPopular: Boolean(row.isPopular),
    })));
  }

  if (request.method === 'GET' && route === '/api/orders') {
    const user = authenticate(request);
    const orders = database.prepare(`
      SELECT orders.id, restaurants.name AS restaurantName, orders.total,
             orders.status, orders.created_at AS createdAt,
             orders.payment_method AS paymentMethod,
             orders.payment_status AS paymentStatus,
             COALESCE(SUM(order_items.quantity), 0) AS itemCount
      FROM orders
      JOIN restaurants ON restaurants.id = orders.restaurant_id
      LEFT JOIN order_items ON order_items.order_id = orders.id
      WHERE orders.user_id = ?
      GROUP BY orders.id
      ORDER BY orders.id DESC
    `).all(user.id).map((order) => ({ ...order, itemCount: Number(order.itemCount) }));
    return send(response, 200, orders);
  }

  if (request.method === 'POST' && route === '/api/payments/authorize') {
    const user = authenticate(request);
    const body = await readJson(request);
    requireObject(body);
    if (body.method !== 'card') {
      throw new HttpError(400, 'Only card payments can be authorized here.');
    }
    if (typeof body.lastFour !== 'string' || !/^\d{4}$/.test(body.lastFour)) {
      throw new HttpError(400, 'Enter a valid card number.');
    }
    const basket = resolveItems(body.items);
    const failed = body.lastFour === '0002';
    const result = database.prepare(`
      INSERT INTO payments (user_id, amount, method, last_four, status)
      VALUES (?, ?, 'card', ?, ?)
    `).run(user.id, basket.total, body.lastFour, failed ? 'failed' : 'authorized');
    const payment = {
      paymentId: Number(result.lastInsertRowid),
      amount: basket.total,
      status: failed ? 'failed' : 'authorized',
      cardLastFour: body.lastFour,
      message: failed ? 'Your bank declined this test card. Try another card or choose cash on delivery.' : 'Payment authorized successfully.',
    };
    return send(response, failed ? 402 : 201, payment);
  }

  const orderMatch = route.match(/^\/api\/orders\/(\d+)$/);
  if (request.method === 'GET' && orderMatch) {
    const user = authenticate(request);
    const belongsToUser = database.prepare(
      'SELECT id FROM orders WHERE id = ? AND user_id = ?',
    ).get(Number(orderMatch[1]), user.id);
    if (!belongsToUser) return send(response, 404, { error: 'Order not found.' });
    const order = getOrder(Number(orderMatch[1]));
    return order
      ? send(response, 200, order)
      : send(response, 404, { error: 'Order not found.' });
  }

  if (request.method === 'PATCH' && orderMatch) {
    const configuredAdminKey = process.env.API_ADMIN_KEY;
    const providedAdminKey = request.headers['x-admin-key'];
    if (!configuredAdminKey || typeof providedAdminKey !== 'string') {
      throw new HttpError(403, 'Order status updates require an operator API key.');
    }
    const expectedKey = Buffer.from(configuredAdminKey);
    const receivedKey = Buffer.from(providedAdminKey);
    if (expectedKey.length !== receivedKey.length || !timingSafeEqual(expectedKey, receivedKey)) {
      throw new HttpError(403, 'Order status updates require an operator API key.');
    }
    const body = await readJson(request);
    if (body === null || typeof body !== 'object' || Array.isArray(body)) {
      return send(response, 400, { error: 'Request body must be a JSON object.' });
    }
    const allowedStatuses = ['Confirmed', 'Preparing', 'On the way', 'Delivered'];
    if (!allowedStatuses.includes(body.status)) {
      return send(response, 400, { error: 'Status must be Confirmed, Preparing, On the way, or Delivered.' });
    }
    const currentOrder = getOrder(Number(orderMatch[1]));
    if (!currentOrder) return send(response, 404, { error: 'Order not found.' });
    const currentIndex = allowedStatuses.indexOf(currentOrder.status);
    const nextIndex = allowedStatuses.indexOf(body.status);
    if (nextIndex < currentIndex || nextIndex > currentIndex + 1) {
      return send(response, 409, { error: 'Order statuses must move forward one step at a time.' });
    }
    database.prepare('UPDATE orders SET status = ? WHERE id = ?')
      .run(body.status, Number(orderMatch[1]));
    return send(response, 200, getOrder(Number(orderMatch[1])));
  }

  if (request.method === 'POST' && route === '/api/orders') {
    const user = authenticate(request);
    const body = await readJson(request);
    requireObject(body);
    const address = typeof body.address === 'string' ? body.address.trim() : '';
    if (address.length < 5 || address.length > 300) {
      throw new HttpError(400, 'Enter a delivery address between 5 and 300 characters.');
    }
    const basket = resolveItems(body.items);
    const paymentMethod = body.paymentMethod === 'card' ? 'card' : body.paymentMethod;
    if (!['cash', 'card'].includes(paymentMethod)) {
      throw new HttpError(400, 'Choose cash on delivery or card payment.');
    }
    let paymentStatus = 'pending';
    let paymentId = null;
    if (paymentMethod === 'card') {
      const paymentIdInput = Number(body.paymentId);
      if (!Number.isSafeInteger(paymentIdInput) || paymentIdInput < 1) {
        throw new HttpError(402, 'Complete card payment before placing your order.');
      }
      const payment = database.prepare(`
        SELECT id, amount, status FROM payments WHERE id = ? AND user_id = ?
      `).get(paymentIdInput, user.id);
      if (!payment || payment.status !== 'authorized') {
        throw new HttpError(402, 'Complete card payment before placing your order.');
      }
      if (Math.abs(payment.amount - basket.total) > 0.001) {
        throw new HttpError(409, 'Your cart changed after payment. Please try checkout again.');
      }
      paymentId = payment.id;
      paymentStatus = 'paid';
    }
    const createOrder = () => {
      if (paymentId !== null) {
        database.prepare('UPDATE payments SET status = ? WHERE id = ?')
          .run('paid', paymentId);
      }
      const result = database.prepare(`
        INSERT INTO orders (
          restaurant_id, address, subtotal, delivery_fee, total,
          user_id, payment_id, payment_method, payment_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        basket.restaurantId,
        address,
        basket.subtotal,
        basket.deliveryFee,
        basket.total,
        user.id,
        paymentId,
        paymentMethod,
        paymentStatus,
      );
      const orderId = Number(result.lastInsertRowid);
      const insertItem = database.prepare(`
        INSERT INTO order_items (order_id, menu_item_id, name, price, quantity)
        VALUES (?, ?, ?, ?, ?)
      `);
      for (const item of basket.items) {
        insertItem.run(orderId, item.id, item.name, item.price, basket.quantities.get(item.id));
      }
      return orderId;
    };
    return send(response, 201, getOrder(withTransaction(createOrder)));
  }

  return send(response, 404, { error: 'Route not found.' });
}

const server = createServer((request, response) => {
  handle(request, response).catch((error) => {
    if (error instanceof HttpError) {
      return send(response, error.status, { error: error.message });
    }
    console.error('API request failed:', error);
    if (!response.headersSent) send(response, 500, { error: 'An unexpected server error occurred.' });
    else response.destroy(error);
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Savor API listening on http://localhost:${server.address().port}`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    server.close(() => {
      database.close();
      process.exit(0);
    });
  });
}

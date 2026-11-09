-- =====================================================================
--  Weirdo Comics — Sistema web de inventario, proveedores, pedidos y ventas
--  Script de base de datos: esquema + datos de prueba + consultas
--  Motor: MySQL 8.0+ / MariaDB 10.5+   |   Juego de caracteres: utf8mb4
--  Normalización: 3FN (ver sección "Normalización" del documento)
-- =====================================================================

CREATE DATABASE weirdo_comics CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE weirdo_comics;

-- =====================================================================
--  1. ESQUEMA (DDL)
-- =====================================================================

-- Catálogo de roles (Administrador, Cajero, Encargado de Almacén)
CREATE TABLE rol (
    id_rol      INT          NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(30)  NOT NULL,
    CONSTRAINT pk_rol        PRIMARY KEY (id_rol),
    CONSTRAINT uq_rol_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

CREATE TABLE usuario (
    id_usuario           INT          NOT NULL AUTO_INCREMENT,
    id_rol               INT          NOT NULL,
    nombre               VARCHAR(100) NOT NULL,
    correo               VARCHAR(100) NOT NULL,                 -- RN-001
    telefono             VARCHAR(20)  NULL,
    contrasena           VARCHAR(255) NOT NULL,                 -- cifrada (RNF-02); el mínimo de 8 caracteres (RN-002) se valida en la app antes de cifrar
    requiere_cambio_clave BOOLEAN     NOT NULL DEFAULT 1,       -- RN-004
    estado               BOOLEAN      NOT NULL DEFAULT 1,       -- RN-003 (baja lógica)
    ultimo_acceso        DATETIME     NULL,
    CONSTRAINT pk_usuario        PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_correo UNIQUE (correo),
    CONSTRAINT fk_usuario_rol    FOREIGN KEY (id_rol) REFERENCES rol (id_rol)
) ENGINE=InnoDB;

CREATE TABLE categoria (
    id_categoria INT          NOT NULL AUTO_INCREMENT,
    nombre       VARCHAR(60)  NOT NULL,
    tipo         VARCHAR(20)  NOT NULL,                         -- 'Cómic' o 'Artículo'
    CONSTRAINT pk_categoria        PRIMARY KEY (id_categoria),
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre),
    CONSTRAINT ck_categoria_tipo   CHECK (tipo IN ('Cómic', 'Artículo'))
) ENGINE=InnoDB;

CREATE TABLE producto (
    id_producto   INT           NOT NULL AUTO_INCREMENT,
    id_categoria  INT           NOT NULL,
    isbn_codigo   VARCHAR(50)   NOT NULL,                       -- RN-006
    titulo        VARCHAR(150)  NOT NULL,
    autor_marca   VARCHAR(100)  NULL,
    costo         DECIMAL(10,2) NOT NULL,
    precio        DECIMAL(10,2) NOT NULL,
    stock         INT           NOT NULL DEFAULT 0,
    stock_minimo  INT           NOT NULL DEFAULT 3,             -- RN-010
    stock_maximo  INT           NULL,
    estado        BOOLEAN       NOT NULL DEFAULT 1,
    CONSTRAINT pk_producto        PRIMARY KEY (id_producto),
    CONSTRAINT uq_producto_isbn   UNIQUE (isbn_codigo),
    CONSTRAINT fk_producto_cat    FOREIGN KEY (id_categoria) REFERENCES categoria (id_categoria),
    CONSTRAINT ck_producto_precio CHECK (precio > costo),       -- RN-005
    CONSTRAINT ck_producto_stock  CHECK (stock >= 0)
) ENGINE=InnoDB;

CREATE TABLE proveedor (
    id_proveedor INT          NOT NULL AUTO_INCREMENT,
    empresa      VARCHAR(100) NOT NULL,
    rfc          VARCHAR(13)  NOT NULL,
    contacto     VARCHAR(100) NOT NULL,
    telefono     VARCHAR(20)  NOT NULL,                         -- RN-013
    email        VARCHAR(100) NOT NULL,                         -- RN-013
    terminos     VARCHAR(200) NULL,
    estado       BOOLEAN      NOT NULL DEFAULT 1,               -- RN-012 (desactivación lógica)
    CONSTRAINT pk_proveedor     PRIMARY KEY (id_proveedor),
    CONSTRAINT uq_proveedor_rfc UNIQUE (rfc)
) ENGINE=InnoDB;

CREATE TABLE pedido (
    id_pedido              INT         NOT NULL AUTO_INCREMENT,
    id_proveedor           INT         NOT NULL,
    id_usuario             INT         NOT NULL,                -- quien emite el pedido
    fecha_solicitud        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega_esperada DATE        NULL,
    fecha_recepcion        DATETIME    NULL,
    estado                 VARCHAR(20) NOT NULL DEFAULT 'Creado',
    CONSTRAINT pk_pedido      PRIMARY KEY (id_pedido),
    CONSTRAINT fk_pedido_prov FOREIGN KEY (id_proveedor) REFERENCES proveedor (id_proveedor),
    CONSTRAINT fk_pedido_usu  FOREIGN KEY (id_usuario)   REFERENCES usuario (id_usuario),
    CONSTRAINT ck_pedido_est  CHECK (estado IN ('Creado', 'Enviado', 'Recibido'))
) ENGINE=InnoDB;

-- Resuelve la relación muchos a muchos Pedido - Producto
CREATE TABLE detalle_pedido (
    id_detalle_pedido INT           NOT NULL AUTO_INCREMENT,
    id_pedido         INT           NOT NULL,
    id_producto       INT           NOT NULL,
    cantidad          INT           NOT NULL,
    costo_unitario    DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_detalle_pedido  PRIMARY KEY (id_detalle_pedido),
    CONSTRAINT uq_detalle_pedido  UNIQUE (id_pedido, id_producto),
    CONSTRAINT fk_dped_pedido     FOREIGN KEY (id_pedido)   REFERENCES pedido (id_pedido) ON DELETE CASCADE,
    CONSTRAINT fk_dped_producto   FOREIGN KEY (id_producto) REFERENCES producto (id_producto),
    CONSTRAINT ck_dped_cantidad   CHECK (cantidad > 0)
) ENGINE=InnoDB;

CREATE TABLE venta (
    id_venta     INT           NOT NULL AUTO_INCREMENT,
    id_usuario   INT           NOT NULL,                        -- cajero que cobra
    folio        VARCHAR(20)   NOT NULL,                        -- folio del ticket (RN-014)
    fecha        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal     DECIMAL(10,2) NOT NULL,
    descuento    DECIMAL(10,2) NOT NULL DEFAULT 0,              -- RN-008
    impuestos    DECIMAL(10,2) NOT NULL DEFAULT 0,
    total        DECIMAL(10,2) NOT NULL,
    forma_pago   VARCHAR(20)   NOT NULL,
    monto_pagado DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_venta       PRIMARY KEY (id_venta),
    CONSTRAINT uq_venta_folio UNIQUE (folio),
    CONSTRAINT fk_venta_usu   FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario),
    CONSTRAINT ck_venta_pago  CHECK (forma_pago IN ('Efectivo', 'Tarjeta', 'Transferencia')),
    CONSTRAINT ck_venta_monto CHECK (monto_pagado >= total)
) ENGINE=InnoDB;

CREATE TABLE detalle_venta (
    id_detalle      INT           NOT NULL AUTO_INCREMENT,
    id_venta        INT           NOT NULL,
    id_producto     INT           NOT NULL,
    cantidad        INT           NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,                     -- precio vigente al momento de la venta
    CONSTRAINT pk_detalle_venta  PRIMARY KEY (id_detalle),
    CONSTRAINT uq_detalle_venta  UNIQUE (id_venta, id_producto),
    CONSTRAINT fk_dven_venta     FOREIGN KEY (id_venta)    REFERENCES venta (id_venta),
    CONSTRAINT fk_dven_producto  FOREIGN KEY (id_producto) REFERENCES producto (id_producto),
    CONSTRAINT ck_dven_cantidad  CHECK (cantidad > 0)
) ENGINE=InnoDB;

-- Bitácora (kardex) de entradas, salidas y ajustes de inventario
CREATE TABLE movimiento_inventario (
    id_movimiento INT          NOT NULL AUTO_INCREMENT,
    id_producto   INT          NOT NULL,
    id_usuario    INT          NOT NULL,
    tipo          VARCHAR(10)  NOT NULL,
    cantidad      INT          NOT NULL,
    fecha         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo        VARCHAR(150) NULL,
    CONSTRAINT pk_movimiento      PRIMARY KEY (id_movimiento),
    CONSTRAINT fk_mov_producto    FOREIGN KEY (id_producto) REFERENCES producto (id_producto),
    CONSTRAINT fk_mov_usuario     FOREIGN KEY (id_usuario)  REFERENCES usuario (id_usuario),
    CONSTRAINT ck_mov_tipo        CHECK (tipo IN ('Entrada', 'Salida', 'Ajuste')),
    CONSTRAINT ck_mov_cantidad    CHECK (cantidad > 0)
) ENGINE=InnoDB;

CREATE INDEX idx_producto_titulo ON producto (titulo);
CREATE INDEX idx_venta_fecha     ON venta (fecha);
CREATE INDEX idx_pedido_estado   ON pedido (estado);

-- =====================================================================
--  2. DATOS DE PRUEBA (INSERT)
--  Las contraseñas de ejemplo se guardan con SHA2 solo para pruebas;
--  la aplicación debe usar un hash con sal (por ejemplo bcrypt).
-- =====================================================================

INSERT INTO rol (nombre) VALUES
 ('Administrador'), ('Cajero'), ('Encargado de Almacén');

INSERT INTO usuario (id_rol, nombre, correo, telefono, contrasena, requiere_cambio_clave, estado, ultimo_acceso) VALUES
 (1, 'Mariana López Cruz',     'admin@weirdocomics.mx',   '4421000001', SHA2('Admin2026!', 256), 0, 1, '2026-11-07 09:00:00'),
 (2, 'Carlos Pérez Soto',   'paloma@weirdocomics.mx',  '4421000002', SHA2('Caja2026!', 256),  0, 1, '2026-11-07 10:00:00'),
 (2, 'Luis Hernández Vega',         'david@weirdocomics.mx',   '4421000003', SHA2('Caja2026!', 256),  0, 1, '2026-11-06 17:55:00'),
 (3, 'Ana Torres Rivas',      'judith@weirdocomics.mx',  '4421000004', SHA2('Alma2026!', 256),  0, 1, '2026-11-07 08:30:00'),
 (2, 'Cajero Temporal',           'temporal@weirdocomics.mx', NULL,        SHA2('Temp2026!', 256),  1, 0, NULL);

INSERT INTO categoria (nombre, tipo) VALUES
 ('Superhéroes',      'Cómic'),
 ('Manga',            'Cómic'),
 ('Novela gráfica',   'Cómic'),
 ('Figuras',          'Artículo'),
 ('Playeras',         'Artículo'),
 ('Pósters',          'Artículo');

INSERT INTO proveedor (empresa, rfc, contacto, telefono, email, terminos, estado) VALUES
 ('Distribuidora Panini México', 'DPM010101AB1', 'Laura Mendoza',  '5551230001', 'ventas@paninimx.example',     'Crédito a 30 días',          1),
 ('Importadora Nipón Cómics',    'INC020202CD2', 'Kenji Ortega',   '5551230002', 'pedidos@niponcomics.example', 'Pago anticipado, envío 10 días', 1),
 ('Collectibles MX',             'CMX030303EF3', 'Sofía Villegas', '4421230003', 'contacto@collectibles.example','Crédito a 15 días',          1),
 ('Papelería y Pósters del Sur', 'PPS040404GH4', 'Raúl Trejo',     '3331230004', 'raul@posters.example',        NULL,                          0);

INSERT INTO producto (id_categoria, isbn_codigo, titulo, autor_marca, costo, precio, stock, stock_minimo, stock_maximo, estado) VALUES
 (1, '9788417063221', 'Batman: Año Uno',           'Frank Miller',    180.00, 260.00, 12, 3, 40, 1),
 (1, '9788490247006', 'Spider-Man: Blue',          'Jeph Loeb',       200.00, 290.00,  8, 3, 30, 1),
 (3, '9788417355005', 'Watchmen',                  'Alan Moore',      320.00, 450.00,  5, 3, 20, 1),
 (2, '9786077610001', 'Naruto Vol. 1',             'Masashi Kishimoto', 70.00, 120.00, 20, 5, 60, 1),
 (2, '9786077610018', 'One Piece Vol. 1',          'Eiichiro Oda',     75.00, 125.00, 18, 5, 60, 1),
 (2, '9786077610025', 'Berserk Deluxe Vol. 1',     'Kentaro Miura',   480.00, 690.00,  3, 3, 10, 1),
 (3, '9788426111111', 'Maus',                      'Art Spiegelman',  250.00, 360.00,  6, 3, 20, 1),
 (4, '7501234500011', 'Figura Iron Man 15 cm',     'Marvel',          250.00, 399.00,  7, 3, 15, 1),
 (4, '7501234500028', 'Figura Goku Super Saiyajin','Bandai',          280.00, 450.00,  2, 3, 15, 1),
 (5, '7501234500035', 'Playera Batman Logo M',     'DC Comics',       110.00, 220.00, 15, 4, 40, 1),
 (6, '7501234500042', 'Póster Avengers 60x90',     'Marvel',           35.00,  90.00, 25, 5, 60, 1),
 (6, '7501234500059', 'Póster Akira',              'Katsuhiro Otomo',  35.00,  95.00,  0, 5, 60, 1);

INSERT INTO pedido (id_proveedor, id_usuario, fecha_solicitud, fecha_entrega_esperada, fecha_recepcion, estado) VALUES
 (1, 1, '2026-10-20 10:00:00', '2026-10-30', '2026-10-29 12:30:00', 'Recibido'),
 (2, 1, '2026-10-25 11:15:00', '2026-11-05', '2026-11-04 09:45:00', 'Recibido'),
 (3, 1, '2026-11-03 16:00:00', '2026-11-12', NULL,                  'Enviado'),
 (2, 1, '2026-11-07 09:20:00', '2026-11-20', NULL,                  'Creado');

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, costo_unitario) VALUES
 (1, 1, 10, 180.00), (1, 2,  6, 200.00),
 (2, 4, 20,  70.00), (2, 5, 20,  75.00),
 (3, 8,  5, 250.00), (3, 9,  4, 280.00),
 (4, 6,  4, 480.00), (4, 5, 10,  75.00);

-- Ventas (descuento del 10 % sobre cómics cuando se compran 5 o más — RN-008;
-- IVA del 16 % solo sobre artículos)
INSERT INTO venta (id_usuario, folio, fecha, subtotal, descuento, impuestos, total, forma_pago, monto_pagado) VALUES
 (2, 'T-000001', '2026-11-02 11:15:00',  610.00,  61.00,  0.00,  549.00, 'Efectivo',      600.00),
 (2, 'T-000002', '2026-11-03 16:40:00',  400.00,   0.00, 64.00,  464.00, 'Tarjeta',       464.00),
 (3, 'T-000003', '2026-11-05 12:05:00',  659.00,   0.00, 63.84,  722.84, 'Efectivo',      800.00),
 (3, 'T-000004', '2026-11-06 18:20:00', 1465.00, 146.50,  0.00, 1318.50, 'Transferencia', 1318.50),
 (2, 'T-000005', '2026-11-07 10:30:00',  450.00,   0.00, 72.00,  522.00, 'Tarjeta',       522.00);

INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario) VALUES
 (1, 4, 3, 120.00), (1, 5, 2, 125.00),
 (2, 10, 1, 220.00), (2, 11, 2,  90.00),
 (3, 1, 1, 260.00), (3, 8, 1, 399.00),
 (4, 3, 1, 450.00), (4, 7, 1, 360.00), (4, 2, 1, 290.00), (4, 4, 2, 120.00), (4, 5, 1, 125.00),
 (5, 9, 1, 450.00);

INSERT INTO movimiento_inventario (id_producto, id_usuario, tipo, cantidad, fecha, motivo) VALUES
 (1, 4, 'Entrada', 10, '2026-10-29 12:30:00', 'Recepción pedido 1'),
 (2, 4, 'Entrada',  6, '2026-10-29 12:30:00', 'Recepción pedido 1'),
 (4, 4, 'Entrada', 20, '2026-11-04 09:45:00', 'Recepción pedido 2'),
 (5, 4, 'Entrada', 20, '2026-11-04 09:45:00', 'Recepción pedido 2'),
 (4, 2, 'Salida',   3, '2026-11-02 11:15:00', 'Venta T-000001'),
 (5, 2, 'Salida',   2, '2026-11-02 11:15:00', 'Venta T-000001'),
 (9, 4, 'Ajuste',   1, '2026-11-07 08:40:00', 'Ajuste por conteo físico (pieza dañada)');

-- =====================================================================
--  3. CONSULTAS (por interfaz)
-- =====================================================================

-- ---- I-01 Login: validar credenciales y rol (RN-003: solo cuentas activas)
SELECT u.id_usuario, u.nombre, r.nombre AS rol, u.requiere_cambio_clave
FROM usuario u
JOIN rol r ON r.id_rol = u.id_rol
WHERE u.correo = 'admin@weirdocomics.mx'
  AND u.contrasena = SHA2('Admin2026!', 256)
  AND u.estado = 1;

-- ---- I-02 Dashboard: indicadores globales
SELECT
  (SELECT COUNT(*)                FROM producto WHERE estado = 1)            AS total_productos,
  (SELECT COALESCE(SUM(stock),0)  FROM producto WHERE estado = 1)            AS stock_total,
  (SELECT COALESCE(SUM(total),0)  FROM venta WHERE DATE(fecha) = '2026-11-07') AS ventas_del_dia,
  (SELECT COUNT(*)                FROM pedido WHERE estado <> 'Recibido')    AS pedidos_pendientes;

-- Ventas por día de los últimos 30 días (gráfica)
SELECT DATE(fecha) AS dia, COUNT(*) AS num_ventas, SUM(total) AS total_dia
FROM venta
WHERE fecha >= '2026-11-08' - INTERVAL 30 DAY
GROUP BY DATE(fecha)
ORDER BY dia;

-- Últimas ventas registradas
SELECT v.folio, v.fecha, u.nombre AS cajero, v.total
FROM venta v
JOIN usuario u ON u.id_usuario = v.id_usuario
ORDER BY v.fecha DESC
LIMIT 5;

-- ---- I-03 Gestión de productos: búsqueda por título, autor o ISBN
SELECT p.id_producto, p.isbn_codigo, p.titulo, p.autor_marca,
       c.nombre AS categoria, c.tipo, p.precio, p.stock
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.estado = 1
  AND (p.titulo LIKE '%man%' OR p.autor_marca LIKE '%man%' OR p.isbn_codigo LIKE '%man%')
ORDER BY p.titulo;

-- ---- I-04 Control de inventario: stock bajo (RN-010)
SELECT p.id_producto, p.titulo, p.stock, p.stock_minimo,
       CASE WHEN p.stock = 0 THEN 'Agotado' ELSE 'Stock crítico' END AS situacion
FROM producto p
WHERE p.estado = 1 AND p.stock <= p.stock_minimo
ORDER BY p.stock, p.titulo;

-- Movimientos de inventario de un producto (kardex)
SELECT m.fecha, m.tipo, m.cantidad, m.motivo, u.nombre AS responsable
FROM movimiento_inventario m
JOIN usuario u ON u.id_usuario = m.id_usuario
WHERE m.id_producto = 4
ORDER BY m.fecha;

-- ---- I-05 Gestión de proveedores: proveedores activos con pedidos en curso (RN-012)
SELECT pr.id_proveedor, pr.empresa, pr.contacto, pr.telefono, pr.email,
       COUNT(pe.id_pedido) AS pedidos_en_curso
FROM proveedor pr
LEFT JOIN pedido pe ON pe.id_proveedor = pr.id_proveedor AND pe.estado IN ('Creado', 'Enviado')
WHERE pr.estado = 1
GROUP BY pr.id_proveedor, pr.empresa, pr.contacto, pr.telefono, pr.email
ORDER BY pr.empresa;

-- ---- I-06 Gestión de pedidos: listado con proveedor, piezas y monto
SELECT pe.id_pedido, pr.empresa, pe.fecha_solicitud, pe.fecha_entrega_esperada, pe.estado,
       SUM(dp.cantidad)                      AS piezas,
       SUM(dp.cantidad * dp.costo_unitario)  AS monto
FROM pedido pe
JOIN proveedor pr      ON pr.id_proveedor = pe.id_proveedor
JOIN detalle_pedido dp ON dp.id_pedido    = pe.id_pedido
GROUP BY pe.id_pedido, pr.empresa, pe.fecha_solicitud, pe.fecha_entrega_esperada, pe.estado
ORDER BY pe.fecha_solicitud DESC;

-- Detalle de un pedido
SELECT p.titulo, dp.cantidad, dp.costo_unitario, dp.cantidad * dp.costo_unitario AS importe
FROM detalle_pedido dp
JOIN producto p ON p.id_producto = dp.id_producto
WHERE dp.id_pedido = 3;

-- ---- I-07 Nueva venta: ticket de una venta (RF-09)
SELECT v.folio, v.fecha, u.nombre AS cajero,
       p.titulo, dv.cantidad, dv.precio_unitario,
       dv.cantidad * dv.precio_unitario AS importe,
       v.subtotal, v.descuento, v.impuestos, v.total,
       v.forma_pago, v.monto_pagado, v.monto_pagado - v.total AS cambio
FROM venta v
JOIN usuario u        ON u.id_usuario  = v.id_usuario
JOIN detalle_venta dv ON dv.id_venta   = v.id_venta
JOIN producto p       ON p.id_producto = dv.id_producto
WHERE v.folio = 'T-000004';

-- ---- I-08 Reportes
-- Ventas por rango de fechas (RN-015: fecha inicial <= fecha final)
SELECT DATE(fecha) AS dia, COUNT(*) AS ventas, SUM(total) AS importe
FROM venta
WHERE fecha BETWEEN '2026-11-01 00:00:00' AND '2026-11-07 23:59:59'
GROUP BY DATE(fecha)
ORDER BY dia;

-- Productos más vendidos
SELECT p.titulo, SUM(dv.cantidad) AS unidades, SUM(dv.cantidad * dv.precio_unitario) AS importe
FROM detalle_venta dv
JOIN producto p ON p.id_producto = dv.id_producto
GROUP BY p.id_producto, p.titulo
ORDER BY unidades DESC, importe DESC
LIMIT 5;

-- Ventas por categoría
SELECT c.nombre AS categoria, SUM(dv.cantidad) AS unidades,
       SUM(dv.cantidad * dv.precio_unitario) AS importe
FROM detalle_venta dv
JOIN producto p  ON p.id_producto  = dv.id_producto
JOIN categoria c ON c.id_categoria = p.id_categoria
GROUP BY c.id_categoria, c.nombre
ORDER BY importe DESC;

-- Ventas por cajero
SELECT u.nombre AS cajero, COUNT(*) AS ventas, SUM(v.total) AS importe
FROM venta v
JOIN usuario u ON u.id_usuario = v.id_usuario
GROUP BY u.id_usuario, u.nombre
ORDER BY importe DESC;

-- Compras a proveedores recibidas por proveedor
SELECT pr.empresa, COUNT(DISTINCT pe.id_pedido) AS pedidos_recibidos,
       SUM(dp.cantidad * dp.costo_unitario) AS monto
FROM pedido pe
JOIN proveedor pr      ON pr.id_proveedor = pe.id_proveedor
JOIN detalle_pedido dp ON dp.id_pedido    = pe.id_pedido
WHERE pe.estado = 'Recibido'
GROUP BY pr.id_proveedor, pr.empresa;

-- ---- I-09 Administración de usuarios
SELECT u.id_usuario, u.nombre, u.correo, r.nombre AS rol,
       IF(u.estado = 1, 'Activo', 'Inactivo') AS estado, u.ultimo_acceso
FROM usuario u
JOIN rol r ON r.id_rol = u.id_rol
ORDER BY r.nombre, u.nombre;

-- =====================================================================
--  4. OPERACIONES DE EJEMPLO (se revierten con ROLLBACK para poder
--     ejecutar el script varias veces)
-- =====================================================================

-- Registrar una venta y descontar inventario (RN-007, RN-009)
START TRANSACTION;
  INSERT INTO venta (id_usuario, folio, fecha, subtotal, descuento, impuestos, total, forma_pago, monto_pagado)
  VALUES (2, 'T-000006', NOW(), 125.00, 0.00, 0.00, 125.00, 'Efectivo', 150.00);
  INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
  VALUES (LAST_INSERT_ID(), 5, 1, 125.00);
  UPDATE producto SET stock = stock - 1 WHERE id_producto = 5 AND stock >= 1;
  INSERT INTO movimiento_inventario (id_producto, id_usuario, tipo, cantidad, motivo)
  VALUES (5, 2, 'Salida', 1, 'Venta T-000006');
  SELECT id_producto, titulo, stock FROM producto WHERE id_producto = 5;
ROLLBACK;

-- Recibir un pedido y aumentar inventario (RN-011)
START TRANSACTION;
  UPDATE pedido SET estado = 'Recibido', fecha_recepcion = NOW() WHERE id_pedido = 3 AND estado = 'Enviado';
  UPDATE producto p
  JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
  SET p.stock = p.stock + dp.cantidad
  WHERE dp.id_pedido = 3;
  SELECT p.titulo, p.stock FROM producto p JOIN detalle_pedido dp ON dp.id_producto = p.id_producto WHERE dp.id_pedido = 3;
ROLLBACK;

-- Baja lógica de un usuario (RN-003): no se borra su historial de ventas
START TRANSACTION;
  UPDATE usuario SET estado = 0 WHERE id_usuario = 3;
  SELECT id_usuario, nombre, estado FROM usuario WHERE id_usuario = 3;
ROLLBACK;

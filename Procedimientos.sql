
CREATE OR REPLACE PROCEDURE registrarTipoCliente(
    p_idtipo IN INTEGER DEFAULT NULL,
    p_nombre IN VARCHAR2,
    p_descripcion IN VARCHAR2
)
IS
    v_idtipo INTEGER;
BEGIN
    -- Asignar el ID proporcionado o generar uno nuevo
    IF p_idtipo IS NOT NULL THEN
        v_idtipo := p_idtipo;
    ELSE
        SELECT NVL(MAX(idtipo), 0) + 1 INTO v_idtipo FROM tipocliente;
    END IF;

    -- Insertar nuevo tipo de cliente
    INSERT INTO tipocliente(idtipo, nombre, descripción)
    VALUES (v_idtipo, p_nombre, p_descripcion);

    -- Confirmar la inserción
    DBMS_OUTPUT.PUT_LINE('Tipo de cliente registrado correctamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al registrar el tipo de cliente: ' || SQLERRM);
END;
CREATE OR REPLACE PROCEDURE registrarCliente(
    p_IdCliente     IN INTEGER,
    p_Nombre        IN VARCHAR2,
    p_Apellidos     IN VARCHAR2,
    p_Telefonos     IN VARCHAR2,
    p_Correos       IN VARCHAR2,
    p_Usuario       IN VARCHAR2,
    p_Contraseña    IN VARCHAR2,
    p_TipoCliente   IN INTEGER
)
AS
    v_IdCorreo      INTEGER;
    v_IdTelefono    INTEGER;
BEGIN
    -- Insertar el cliente
    INSERT INTO cliente (idcliente, nombre, apellidos, usuario, contraseña, idtipo)
    VALUES (p_IdCliente, p_Nombre, p_Apellidos, p_Usuario, p_Contraseña, p_TipoCliente);

    -- Insertar correos del cliente (pueden ser múltiples)
    FOR c IN (SELECT trim(regexp_substr(p_Correos, '[^|]+', 1, level)) correo
              FROM dual
              CONNECT BY regexp_substr(p_Correos, '[^|]+', 1, level) IS NOT NULL)
    LOOP
        INSERT INTO correo (id_correo, idcliente, correo)
        VALUES (correo_seq.NEXTVAL, p_IdCliente, c.correo);
    END LOOP;

    -- Insertar teléfonos del cliente (pueden ser múltiples)
    FOR t IN (SELECT trim(regexp_substr(p_Telefonos, '[^-|]+', 1, level)) telefono
              FROM dual
              CONNECT BY regexp_substr(p_Telefonos, '[^-|]+', 1, level) IS NOT NULL)
    LOOP
        -- Verificar si el teléfono tiene más de 12 caracteres
        IF LENGTH(t.telefono) > 12 THEN
            -- Truncar el teléfono a 12 caracteres
            t.telefono := SUBSTR(t.telefono, 1, 12);
        END IF;

        -- Insertar el teléfono
        INSERT INTO telefono (id_telefono, idcliente, telefono)
        VALUES (telefono_seq.NEXTVAL, p_IdCliente, t.telefono);
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Cliente registrado exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al registrar el cliente: ' || SQLERRM);
END;
CREATE OR REPLACE PROCEDURE registrarTipoCuenta(
    p_Codigo       IN INTEGER,
    p_Nombre       IN VARCHAR2,
    p_Descripcion  IN VARCHAR2
)
AS
BEGIN
    -- Insertar el tipo de cuenta
    INSERT INTO tipocuenta (codigo, nombre, descripción)
    VALUES (p_Codigo, p_Nombre, p_Descripcion);
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Tipo de cuenta registrado exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al registrar el tipo de cuenta: ' || SQLERRM);
END;
CREATE OR REPLACE PROCEDURE registrarCuenta(
    p_IdCuenta          IN INTEGER,
    p_MontoApertura     IN NUMBER,
    p_SaldoCuenta       IN NUMBER DEFAULT NULL,
    p_Descripcion       IN VARCHAR2,
    p_FechaApertura     IN VARCHAR2 DEFAULT TO_CHAR(CURRENT_TIMESTAMP),
    p_OtrosDetalles     IN VARCHAR2 DEFAULT NULL,
    p_TipoCuenta        IN INTEGER,
    p_IdCliente         IN INTEGER
)
AS
    v_SaldoCuenta   NUMBER(12, 2);
    v_Count         INTEGER;
BEGIN
    -- Validar que el monto de apertura sea positivo
    IF p_MontoApertura <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'El monto de apertura debe ser positivo.');
    END IF;

    -- Validar que el saldo de cuenta sea no negativo
    IF COALESCE(p_SaldoCuenta, 0) < 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'El saldo de cuenta debe ser no negativo.');
    END IF;

    -- Verificar si la cuenta ya existe
    SELECT COUNT(*) INTO v_Count FROM cuenta WHERE id_cuenta = p_IdCuenta;
    IF v_Count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Ya existe una cuenta con ese número.');
    END IF;

    -- Insertar la cuenta
    INSERT INTO cuenta (id_cuenta, monto_apertura, saldo_cuenta, descripción, fecha_de_apertura, otros_detalles, tipo_cuenta, idcliente)
    VALUES (p_IdCuenta, p_MontoApertura, COALESCE(p_SaldoCuenta, 0), p_Descripcion, TO_DATE(p_FechaApertura, 'DD-MM-YYYY HH24:MI:SS'), p_OtrosDetalles, p_TipoCuenta, p_IdCliente);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Cuenta registrada exitosamente.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20004, 'Ya existe una cuenta con ese número.');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al registrar la cuenta: ' || SQLERRM);
END;
CREATE OR REPLACE PROCEDURE crearProductoServicio(
    p_CodigoProductoServicio   IN INTEGER,
    p_Tipo                      IN INTEGER,
    p_Costo                     IN NUMBER DEFAULT NULL,
    p_Descripcion               IN VARCHAR2
)
AS
BEGIN
    -- Validar que el tipo sea 1 (servicio) o 2 (producto)
    IF p_Tipo NOT IN (1, 2) THEN
        RAISE_APPLICATION_ERROR(-20001, 'El tipo debe ser 1 para servicio o 2 para producto.');
    END IF;

    -- Validar que el costo sea requerido para los servicios
    IF p_Tipo = 1 AND p_Costo IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'El costo es obligatorio para los servicios.');
    END IF;

    -- Insertar el producto o servicio
    INSERT INTO productoservicio (cod_ps, tipo, costo, descripcion)
    VALUES (p_CodigoProductoServicio, p_Tipo, p_Costo, p_Descripcion);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Producto o servicio creado exitosamente.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20003, 'Ya existe un producto o servicio con ese código.');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al crear el producto o servicio: ' || SQLERRM);
END;
CREATE OR REPLACE PROCEDURE registrarTipoTransaccion(
    p_CodigoTransaccion IN INTEGER,
    p_Nombre            IN VARCHAR2,
    p_Descripcion       IN VARCHAR2
)
AS
BEGIN
    -- Insertar el tipo de transacción
    INSERT INTO tipotransaccion (codigotransaccion, nombre, descripcion)
    VALUES (p_CodigoTransaccion, p_Nombre, p_Descripcion);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Tipo de transacción registrado exitosamente.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20001, 'Ya existe un tipo de transacción con ese código.');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al registrar el tipo de transacción: ' || SQLERRM);
END;
CREATE OR REPLACE PROCEDURE realizarCompra (
    Id_compra IN INTEGER,
    Fecha IN VARCHAR2,
    Importe_compra IN NUMBER,
    Otros_detalles IN VARCHAR2,
    Cod_ps IN INTEGER,
    Id_cliente IN INTEGER
)
AS
    v_cliente_id INTEGER;
    v_tipo_producto INTEGER;
    fecha_date DATE;
BEGIN
    -- Convertir la fecha de VARCHAR2 a DATE
    fecha_date := TO_DATE(Fecha, 'DD/MM/YYYY');

    -- Validar que el cliente exista
    SELECT COUNT(*) INTO v_cliente_id FROM cliente WHERE idcliente = Id_cliente;
    IF v_cliente_id = 0 THEN
        DBMS_OUTPUT.PUT_LINE('El cliente especificado no existe.');
        RETURN;
    END IF;

    -- Validar que el código del producto/servicio exista y sea único
    SELECT COUNT(*) INTO v_tipo_producto FROM productoservicio WHERE cod_ps = Cod_ps;
    IF v_tipo_producto = 0 THEN
        DBMS_OUTPUT.PUT_LINE('El código del producto/servicio especificado no existe.');
        RETURN;
    END IF;

    -- Insertar la compra
    INSERT INTO compra (id_compra, fecha, importe_compra, otros_detalles, idcliente, cod_ps)
    VALUES (Id_compra, fecha_date, Importe_compra, Otros_detalles, Id_cliente, Cod_ps);

    DBMS_OUTPUT.PUT_LINE('Compra realizada exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al realizar la compra: ' || SQLERRM);
END realizarCompra;
CREATE OR REPLACE PROCEDURE realizarDeposito (
    Id_deposito IN INTEGER,
    Fecha IN VARCHAR2,
    Monto IN NUMBER,
    Otros_detalles IN VARCHAR2,
    Id_cliente IN INTEGER
)
AS
    fecha_date DATE;
BEGIN
    -- Convertir la fecha de VARCHAR2 a DATE
    fecha_date := TO_DATE(Fecha, 'DD/MM/YYYY');

    -- Validar que el cliente exista
    DECLARE
        v_cliente_id INTEGER;
    BEGIN
        SELECT idcliente INTO v_cliente_id FROM cliente WHERE idcliente = Id_cliente;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('El cliente especificado no existe.');
            RETURN;
    END;

    -- Validar que el monto sea mayor que cero
    IF Monto <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('El monto del depósito debe ser mayor que cero.');
        RETURN;
    END IF;

    -- Insertar el depósito
    INSERT INTO deposito (id_deposito, fecha, monto, otros_detalles, idcliente)
    VALUES (Id_deposito, fecha_date, Monto, Otros_detalles, Id_cliente);

    DBMS_OUTPUT.PUT_LINE('Depósito realizado exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al realizar el depósito: ' || SQLERRM);
END realizarDeposito;
CREATE OR REPLACE PROCEDURE realizarDebito (
    Id_debito IN INTEGER,
    Fecha IN VARCHAR2,
    Monto IN NUMBER,
    Otros_detalles IN VARCHAR2,
    Id_cliente IN INTEGER
)
AS
    v_cliente_id INTEGER;
BEGIN
    -- Validar que el cliente exista
    SELECT COUNT(*) INTO v_cliente_id FROM cliente WHERE idcliente = Id_cliente;
    IF v_cliente_id = 0 THEN
        DBMS_OUTPUT.PUT_LINE('El cliente especificado no existe.');
        RETURN;
    END IF;

    -- Validar que el monto sea mayor que cero
    IF Monto <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('El monto debe ser mayor que cero.');
        RETURN;
    END IF;

    -- Insertar el débito
    INSERT INTO debito (id_debito, fecha, monto, otros_detalles, idcliente)
    VALUES (Id_debito, TO_DATE(Fecha, 'DD/MM/YYYY'), Monto, Otros_detalles, Id_cliente);

    DBMS_OUTPUT.PUT_LINE('Débito realizado exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al realizar el débito: ' || SQLERRM);
END realizarDebito;

CREATE OR REPLACE PROCEDURE registrarTransaccion (
    Id_transaccion IN INTEGER,
    Fecha IN VARCHAR2,
    Otros_detalles IN VARCHAR2,
    Id_tipo_transaccion IN INTEGER,
    Id_compra_deposito_debito IN INTEGER,
    No_cuenta IN INTEGER
)
AS
    v_saldo NUMBER;
    v_importe_compra NUMBER;
    v_monto_deposito NUMBER;
    v_monto_debito NUMBER;
BEGIN
    -- Validar que exista el tipo de transacción
    SELECT COUNT(*) INTO v_saldo FROM tipotransaccion WHERE codigotransaccion = Id_tipo_transaccion;
    IF v_saldo = 0 THEN
        DBMS_OUTPUT.PUT_LINE('El tipo de transacción especificado no existe.');
        RETURN;
    END IF;

    -- Validar que exista la compra, depósito o débito correspondiente
    IF Id_tipo_transaccion IN (1, 2, 3) THEN
        IF Id_tipo_transaccion = 1 THEN -- Compra
            SELECT importe_compra INTO v_importe_compra FROM compra WHERE id_compra = Id_compra_deposito_debito;
        ELSIF Id_tipo_transaccion = 2 THEN -- Depósito
            SELECT monto INTO v_monto_deposito FROM deposito WHERE id_deposito = Id_compra_deposito_debito;
        ELSIF Id_tipo_transaccion = 3 THEN -- Débito
            SELECT monto INTO v_monto_debito FROM debito WHERE id_debito = Id_compra_deposito_debito;
        END IF;
        
        IF v_importe_compra IS NULL AND v_monto_deposito IS NULL AND v_monto_debito IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('La compra, depósito o débito especificado no existe.');
            RETURN;
        END IF;
    END IF;

    -- Verificar si la cuenta del cliente existe y obtener su saldo
    SELECT saldo_cuenta INTO v_saldo FROM cuenta WHERE id_cuenta = No_cuenta;
    
    -- Validar que tenga saldo suficiente para débito o compra
    IF Id_tipo_transaccion IN (1, 3) THEN -- Compra o Débito
        IF Id_tipo_transaccion = 1 THEN
            IF v_saldo < v_importe_compra THEN
                DBMS_OUTPUT.PUT_LINE('No hay saldo suficiente para realizar la transacción.');
                RETURN;
            END IF;
        ELSIF Id_tipo_transaccion = 3 THEN
            IF v_saldo < v_monto_debito THEN
                DBMS_OUTPUT.PUT_LINE('No hay saldo suficiente para realizar la transacción.');
                RETURN;
            END IF;
        END IF;
    END IF;

    -- Realizar la transacción
    IF Id_tipo_transaccion = 1 THEN -- Compra
        UPDATE cuenta SET saldo_cuenta = saldo_cuenta - v_importe_compra WHERE id_cuenta = No_cuenta;
    ELSIF Id_tipo_transaccion = 2 THEN -- Depósito
        UPDATE cuenta SET saldo_cuenta = saldo_cuenta + v_monto_deposito WHERE id_cuenta = No_cuenta;
    ELSIF Id_tipo_transaccion = 3 THEN -- Débito
        UPDATE cuenta SET saldo_cuenta = saldo_cuenta - v_monto_debito WHERE id_cuenta = No_cuenta;
    END IF;

    -- Insertar la transacción
    INSERT INTO transaccion (id_transaccion, fecha, otrosdetalles, id_cuenta, codigotransaccion, id_debito, id_deposito, id_compra)
    VALUES (Id_transaccion, TO_DATE(Fecha, 'DD/MM/YYYY'), Otros_detalles, No_cuenta, Id_tipo_transaccion,
            CASE WHEN Id_tipo_transaccion = 3 THEN Id_compra_deposito_debito END,
            CASE WHEN Id_tipo_transaccion = 2 THEN Id_compra_deposito_debito END,
            CASE WHEN Id_tipo_transaccion = 1 THEN Id_compra_deposito_debito END);

    DBMS_OUTPUT.PUT_LINE('Transacción registrada exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al registrar la transacción: ' || SQLERRM);
END registrarTransaccion;

begin
-- registrar transaccion
--              id,      fecha,  otrosdetalles, id_tipo_transaccion, idcompra/deposito/debito, nocuenta
registrarTransaccion(1118, '10/04/2024','', 1, 1113, 3030206080); -- aqui hay error debido a que no se tiene el saldo suficiente para realizar la compra
end;
begin
registrarTransaccion(1115, '10/04/2024','',2, 1114, 3030206080); -- se realia deposito *aqui se puede depositar a una cuenta que no es del cliente
end;
begin
registrarTransaccion(1120, '10/04/2024','este si tiene detalle',3,  1116, 3030206080); -- se realiza un debito
end;
-- visualizar errores al ejecutar un proecdimiento
SHOW ERRORS PROCEDURE registrarTransaccion;

begin
-- registrar transaccion
--              id,      fecha,  otrosdetalles, id_tipo_transaccion, idcompra/deposito/debito, nocuenta
registrarTransaccion(1118, '10/04/2024','', 1,  1113, 3030206080); -- aqui hay error debido a que no se tiene el saldo suficiente para realizar la compra
registrarTransaccion(1115, '10/04/2024','',2, 1114, 3030206080); -- se realia deposito *aqui se puede depositar a una cuenta que no es del cliente
registrarTransaccion(1120, '10/04/2024','este si tiene detalle', 3, 1116, 3030206080); -- se realiza un debito
end;


begin
-- realizar retiro
--              id,      fecha,     monto,  otrosdetalles, idcliente
realizarDebito(1116, '10/04/2024', 100, 'retiro de dinero', 1001);
realizarDebito(1117, '10/04/2024', 0, 'retiro de dinero con error', 1001); --aqui hay error ya que el monto deberia de ser mayor a cero
end;
begin
-- realizar deposito
--              id,      fecha,     monto,  otrosdetalles, idcliente
realizarDeposito(1114, '10/04/2024', 100, 'deposito de dinero', 1001);
realizarDeposito(1115, '10/04/2024', 0, 'deposito de dinero', 1001); --aqui hay error ya que el monto deberia de ser mayor a cero
end;

begin
realizarCompra(1111, '10/04/2024', 40, 'compra de servicio', 18, 1001); --aqui hay error ya que el monto deberia de ser cero por que ya tiene un precio preestablecido por ser un servicio
realizarCompra(1112, '10/04/2024', 0, 'compra de producto', 19, 1001); --aqui hay error debido a que el monto deberia de ser > 0 ya que es un producto y no tiene un precio preestablecido
end;
begin
realizarCompra(1113, '10/04/2024', 50, 'compra de producto', 19, 1001); --aqui esta correcto ya que el monto es mayor a cero y es un producto
end;
BEGIN
realizarCompra(1112, '10/04/2024', 0, 'compra de producto', 19, 1001);
END;
BEGIN
realizarCompra(1111, '10/04/2024', 40, 'compra de servicio', 18, 1001); --aqui hay error ya que el monto deberia de ser cero por que ya tiene un precio preestablecido por ser un servicio
END;
begin
    registrarCuenta(3030206080, 500.00, 800.00, 'Apertura de cuenta con Q500',NULL ,NULL ,5,1001);
    registrarCuenta(3030206081, 600.00, 600.00, 'Apertura de cuenta con Q500','01/04/2024 07:00:00','esta apertura tiene fecha',5,1001);
end;

begin 
crearProductoServicio(18, 1, 50.80, 'Este es un servicio el cual tiene un precio predefinido'); --servicio
crearProductoServicio(19, 2, 0, 'Este es un producto el cual tiene un precio variable'); --producto, tiene un precio de "cero" el cual indica que es variable
end;
BEGIN 
registrarTipoTransaccion(1, 'Compra', 'Transacción de compra');
registrarTipoTransaccion(2, 'Deposito', 'Transacción de deposito');
registrarTipoTransaccion(3, 'Debito', 'Transacción de debito');
END;

--, 
--- habilitar mensajes de conexion 
SET SERVEROUTPUT ON;

begin
registrarTipoCliente(4, 'Cliente Extraordinario', 'Este cliente no esta definido en el enunciado, es un tipo de cliente extra');
registrarTipoCliente(1, 'Cliente 1', 'Este cliente no esta definido en el enunciado, es un tipo de cliente extra');
registrarTipoCliente(2, 'Cliente 2', 'Este cliente no esta definido en el enunciado, es un tipo de cliente extra');
registrarTipoCliente(3, 'Cliente 3', 'Este cliente no esta definido en el enunciado, es un tipo de cliente extra');
end;
begin
registrarCliente(1001, 'Juan Isaac','Perez Lopez','22888080','micorreo@gmail.com','jisaacp2024','12345678','1' );
registrarCliente(1002, 'Maria Isabel','Gonzalez Perez','22805050-22808080','micorreo1@gmail.com|micorreo2@gmail.com','mariauser','12345679','2' );
end;
begin
    registrarTipoCuenta(7,'Cuenta Extraordinaria','Cuenta Extraordinaria a enunciado');
    registrarTipoCuenta(5, 'Cuenta de Ahorro', 'Cuenta de Ahorro');
    registrarTipoCuenta(9, 'Cuenta Monetaria', 'Cuenta Monetaria');
    registrarTipoCuenta(10, 'Cuenta de Cheques', 'Cuenta de Cheques');
end;
begin
registrarCuenta(3030206081, 600.00, 600.00, 'Apertura de cuenta con Q500','01/04/2024 07:00:00','esta apertura tiene fecha',5,1001);
end;
begin 
registrarTransaccion(1118, '10/04/2024','', 1, 1, 1113, 3030206080); -- aqui hay error debido a que no se tiene el saldo suficiente para realizar la compra
registrarTransaccion(1115, '10/04/2024','',2, 2, 1114, 3030206080); -- se realia deposito *aqui se puede depositar a una cuenta que no es del cliente
registrarTransaccion(1120, '10/04/2024','este si tiene detalle',3, 3, 1116, 3030206080); -- se realiza un debito
end;


DELETE FROM transaccion;
DELETE FROM tipotransaccion;
DELETE FROM debito;
DELETE FROM deposito;
DELETE FROM compra;
DELETE FROM productoservicio;
DELETE FROM cuenta;
DELETE FROM tipocuenta;
DELETE FROM telefono;
DELETE FROM correo;
DELETE FROM cliente;
DELETE FROM tipocliente;
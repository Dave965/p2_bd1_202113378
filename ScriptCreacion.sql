--, SET SERVEROUTPUT ON;
--- habilitar mensajes de conexion 
SET SERVEROUTPUT ON;
-- Validaciones 

-- Registrar proceadimientos
CREATE OR REPLACE PROCEDURE registrarTipoCliente(
    p_idtipo IN INTEGER DEFAULT NULL,
    p_nombre IN VARCHAR2,
    p_descripcion IN VARCHAR2
)
IS
    v_idtipo INTEGER;
     v_count INTEGER;
BEGIN
    -- Verificar si el tipo de cliente ya existe
    SELECT COUNT(*) INTO v_count FROM tipocliente WHERE nombre = p_nombre;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: El tipo de cliente ya existe.');
        RETURN;
    END IF;

    IF NOT soloLetras(p_descripcion) THEN
        DBMS_OUTPUT.PUT_LINE('Error: La descripcion debe contener solo letras.');
        RETURN;
    END IF;
    -- Asignar el ID proporcionado o generar uno nuevo
    IF p_idtipo IS NOT NULL THEN
        v_idtipo := p_idtipo;
    ELSE
        SELECT NVL(MAX(idtipo), 0) + 1 INTO v_idtipo FROM tipocliente;
    END IF;

    -- Insertar nuevo tipo de cliente
    INSERT INTO tipocliente(idtipo, nombre, descripcion)
    VALUES (v_idtipo, p_nombre, p_descripcion);

    -- Confirmar la insercion
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
    p_Contrasena    IN VARCHAR2,
    p_TipoCliente   IN INTEGER
)
AS
    v_IdCorreo      INTEGER;
    v_IdTelefono    INTEGER;
    v_usuarioCount integer;
    v_ContrasenaBin RAW(200);
BEGIN
    -- Validar nombre y apellidos
    IF NOT soloLetras(p_Nombre) THEN
        DBMS_OUTPUT.PUT_LINE('Error: El nombre solo debe contener letras.');
        RETURN;
    END IF;
    
    IF NOT soloLetras(p_Apellidos) THEN
        DBMS_OUTPUT.PUT_LINE('Error: Los apellidos solo deben contener letras.');
        RETURN;
    END IF;
    
     -- Verificar si el usuario ya existe
    SELECT COUNT(*) INTO v_UsuarioCount FROM cliente WHERE usuario = p_Usuario;
    IF v_UsuarioCount > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: El usuario ya estï¿½ en uso.');
        RETURN;
    END IF;
    
    v_ContrasenaBin := UTL_RAW.CAST_TO_RAW(p_Contrasena);
    -- Insertar el cliente
    INSERT INTO cliente (idcliente, nombre, apellidos, usuario, contrasena, idtipo, historial)
    VALUES (p_IdCliente, p_Nombre, p_Apellidos, p_Usuario, v_ContrasenaBin, p_TipoCliente, SYSTIMESTAMP);

    -- Insertar correos del cliente (pueden ser mutiples)
    FOR c IN (SELECT trim(regexp_substr(p_Correos, '[^|]+', 1, level)) correo
              FROM dual
              CONNECT BY regexp_substr(p_Correos, '[^|]+', 1, level) IS NOT NULL)
    LOOP
        -- Validar cada correo electrï¿½nico individualmente
        IF NOT validarEmail(c.correo) THEN
            DBMS_OUTPUT.PUT_LINE('Error: El correo electronico "' || c.correo || '" no tiene un formato valido.');
            RETURN;
        END IF;

        INSERT INTO correo (id_correo, idcliente, correo)
        VALUES (correo_seq.NEXTVAL, p_IdCliente, c.correo);
    END LOOP;

    -- Insertar telefonos del cliente (pueden ser multiples)
    FOR t IN (SELECT trim(regexp_substr(p_Telefonos, '[^-|]+', 1, level)) telefono
              FROM dual
              CONNECT BY regexp_substr(p_Telefonos, '[^-|]+', 1, level) IS NOT NULL)
    LOOP
        -- Verificar si el telï¿½fono tiene mï¿½s de 12 caracteres
        IF LENGTH(t.telefono) > 12 THEN
            -- Truncar el telï¿½fono a 12 caracteres
            t.telefono := SUBSTR(t.telefono, 1, 12);
        END IF;
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
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM tipocuenta WHERE codigo = p_Codigo;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: El tipo de cuenta ya existe.');
        RETURN;
    END IF;
    -- Insertar el tipo de cuenta
    INSERT INTO tipocuenta (codigo, nombre, descripcion)
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
    v_TipoCuentaValido INTEGER;
    v_ClienteExistente INTEGER;
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
        RAISE_APPLICATION_ERROR(-20003, 'Ya existe una cuenta con ese nï¿½mero.');
    END IF;

    -- Verificar si el tipo de cuenta es valido
    SELECT COUNT(*) INTO v_TipoCuentaValido FROM tipocuenta WHERE codigo = p_TipoCuenta;
    IF v_TipoCuentaValido = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'El tipo de cuenta no es vï¿½lido.');
    END IF;

    -- Verificar si el cliente existe
    SELECT COUNT(*) INTO v_ClienteExistente FROM cliente WHERE idcliente = p_IdCliente;
    IF v_ClienteExistente = 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'El cliente no existe.');
    END IF;
    
    -- Insertar la cuenta
    INSERT INTO cuenta (id_cuenta, monto_apertura, saldo_cuenta, descripcion, fecha_de_apertura, otros_detalles, tipo_cuenta, idcliente)
    VALUES (p_IdCuenta, p_MontoApertura, COALESCE(p_SaldoCuenta, 0), p_Descripcion, TO_DATE(p_FechaApertura, 'DD-MM-YYYY HH24:MI:SS'), p_OtrosDetalles, p_TipoCuenta, p_IdCliente);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Cuenta registrada exitosamente.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20006, 'Ya existe una cuenta con ese nï¿½mero.');
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
    v_count INTEGER;
BEGIN
     SELECT COUNT(*) INTO v_count FROM productoservicio WHERE cod_ps = p_CodigoProductoServicio;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: Ya existe un producto o servicio con ese cï¿½digo.');
        RETURN;
    END IF;
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
        RAISE_APPLICATION_ERROR(-20003, 'Ya existe un producto o servicio con ese c?digo.');
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
     v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM tipotransaccion WHERE codigotransaccion = p_CodigoTransaccion;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: Ya existe un tipo de transacciï¿½n con ese cï¿½digo.');
        RETURN;
    END IF;
    -- Insertar el tipo de transacci?n
    INSERT INTO tipotransaccion (codigotransaccion, nombre, descripcion)
    VALUES (p_CodigoTransaccion, p_Nombre, p_Descripcion);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Tipo de transacci?n registrado exitosamente.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20001, 'Ya existe un tipo de transacci?n con ese c?digo.');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al registrar el tipo de transacci?n: ' || SQLERRM);
END;

CREATE OR REPLACE PROCEDURE realizarCompra (
    Id_compra IN INTEGER,
    Fecha IN VARCHAR2,
    Importe_compra IN NUMBER,
    Otros_detalles IN VARCHAR2,
    EN_ps IN INTEGER,
    Id_cliente IN INTEGER
)
AS
    v_compra_count INTEGER;
    v_cliente_id INTEGER;
    v_costo_producto NUMBER(12, 2);
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
    -- Obtener el costo del producto/servicio
    SELECT costo INTO v_costo_producto FROM productoservicio WHERE cod_ps = EN_ps AND ROWNUM = 1;
        
    -- Validar que el monto no haya sido modificado para servicios (cuyo costo siempre debe ser 0)
    if v_costo_producto <> 0 and  Importe_compra <> 0 THEN
        
        DBMS_OUTPUT.PUT_LINE('Error: El monto de la compra para este producto debe ser 0 ');
        RETURN;
    end if;

    -- Validar que el monto sea mayor que 0 para productos
    IF v_costo_producto = 0 AND Importe_compra <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: El monto de la compra para productos debe ser mayor que 0.');
        RETURN;
    END IF;
    
    -- Insertar la compra
    INSERT INTO compra (id_compra, fecha, importe_compra, otros_detalles, idcliente, cod_ps)
    VALUES (Id_compra, fecha_date, Importe_compra, Otros_detalles, Id_cliente, EN_ps);

    DBMS_OUTPUT.PUT_LINE('Compra realizada exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al realizar la compra: ' || SQLERRM);
END realizarCompra;

-- realizr compra
begin
realizarCompra(1111, '10/04/2024', 40, 'compra de servicio', 18, 1001); --aqui hay error ya que el monto deberia de ser cero por que ya tiene un precio preestablecido por ser un servicio
realizarCompra(1112, '10/04/2024', 0, 'compra de producto', 19, 1001); --aqui hay error debido a que el monto deberia de ser > 0 ya que es un producto y no tiene un precio preestablecido
realizarCompra(1113, '10/04/2024', 50, 'compra de producto', 19, 1001); --aqui esta correcto ya que el monto es mayor a cero y es un producto
end;
delete from compra;
CREATE OR REPLACE PROCEDURE realizarDeposito (
    Id_deposito IN INTEGER,
    Fecha IN VARCHAR2,
    Monto IN NUMBER,
    Otros_detalles IN VARCHAR2,
    Id_cliente IN INTEGER
)
AS
    v_deposito_count INTEGER;
    fecha_date DATE;
BEGIN
    SELECT COUNT(*) INTO v_deposito_count FROM deposito WHERE id_deposito = Id_deposito;
    IF v_deposito_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: Ya existe un deposito con ese ID.');
        RETURN;
    END IF;
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
        DBMS_OUTPUT.PUT_LINE('El monto del deposito debe ser mayor que cero.');
        RETURN;
    END IF;

    -- Insertar el dep?sito
    INSERT INTO deposito (id_deposito, fecha, monto, otros_detalles, idcliente)
    VALUES (Id_deposito, fecha_date, Monto, Otros_detalles, Id_cliente);

    DBMS_OUTPUT.PUT_LINE('Deposito realizado exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al realizar el deposito: ' || SQLERRM);
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
    v_debito_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_debito_count FROM debito WHERE id_debito = Id_debito;
    IF v_debito_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: Ya existe un dï¿½bito con ese ID.');
        RETURN;
    END IF;
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

    -- Insertar el d?bito
    INSERT INTO debito (id_debito, fecha, monto, otros_detalles, idcliente)
    VALUES (Id_debito, TO_DATE(Fecha, 'DD/MM/YYYY'), Monto, Otros_detalles, Id_cliente);

    DBMS_OUTPUT.PUT_LINE('D?bito realizado exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al realizar el d?bito: ' || SQLERRM);
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
    -- Validar que exista el tipo de transaccion
    SELECT COUNT(*) INTO v_saldo FROM tipotransaccion WHERE codigotransaccion = Id_tipo_transaccion;
    IF v_saldo = 0 THEN
        DBMS_OUTPUT.PUT_LINE('El tipo de transaccion especificado no existe.');
        RETURN;
    END IF;

    -- Validar que exista la compra, dep?sito o d?bito correspondiente
    IF Id_tipo_transaccion IN (1, 2, 3) THEN
        IF Id_tipo_transaccion = 1 THEN -- Compra
            SELECT importe_compra INTO v_importe_compra FROM compra WHERE id_compra = Id_compra_deposito_debito;
        ELSIF Id_tipo_transaccion = 2 THEN -- Deposito
            SELECT monto INTO v_monto_deposito FROM deposito WHERE id_deposito = Id_compra_deposito_debito;
        ELSIF Id_tipo_transaccion = 3 THEN -- D?bito
            SELECT monto INTO v_monto_debito FROM debito WHERE id_debito = Id_compra_deposito_debito;
        END IF;
        
        IF v_importe_compra IS NULL AND v_monto_deposito IS NULL AND v_monto_debito IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('La compra, dep?sito o d?bito especificado no existe.');
            RETURN;
        END IF;
    END IF;

    -- Verificar si la cuenta del cliente existe y obtener su saldo
    SELECT saldo_cuenta INTO v_saldo FROM cuenta WHERE id_cuenta = No_cuenta;
    
    -- Validar que tenga saldo suficiente para debito o compra
    IF Id_tipo_transaccion IN (1, 3) THEN -- Compra o D?bito
        IF Id_tipo_transaccion = 1 THEN
            IF v_saldo < v_importe_compra THEN
                DBMS_OUTPUT.PUT_LINE('No hay saldo suficiente para realizar la transaccion.');
                RETURN;
            END IF;
        ELSIF Id_tipo_transaccion = 3 THEN
            IF v_saldo < v_monto_debito THEN
                DBMS_OUTPUT.PUT_LINE('No hay saldo suficiente para realizar la transaccion.');
                RETURN;
            END IF;
        END IF;
    END IF;

    -- Realizar la transaccion
    IF Id_tipo_transaccion = 1 THEN -- Compra
        UPDATE cuenta SET saldo_cuenta = saldo_cuenta - v_importe_compra WHERE id_cuenta = No_cuenta;
    ELSIF Id_tipo_transaccion = 2 THEN -- Dep?sito
        UPDATE cuenta SET saldo_cuenta = saldo_cuenta + v_monto_deposito WHERE id_cuenta = No_cuenta;
    ELSIF Id_tipo_transaccion = 3 THEN -- D?bito
        UPDATE cuenta SET saldo_cuenta = saldo_cuenta - v_monto_debito WHERE id_cuenta = No_cuenta;
    END IF;

    -- Insertar la transacci?n
    INSERT INTO transaccion (id_transaccion, fecha, otrosdetalles, id_cuenta, codigotransaccion, id_debito, id_deposito, id_compra)
    VALUES (Id_transaccion, TO_DATE(Fecha, 'DD/MM/YYYY'), Otros_detalles, No_cuenta, Id_tipo_transaccion,
            CASE WHEN Id_tipo_transaccion = 3 THEN Id_compra_deposito_debito END,
            CASE WHEN Id_tipo_transaccion = 2 THEN Id_compra_deposito_debito END,
            CASE WHEN Id_tipo_transaccion = 1 THEN Id_compra_deposito_debito END);

    DBMS_OUTPUT.PUT_LINE('Transacci?n registrada exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al registrar la transacci?n: ' || SQLERRM);
END registrarTransaccion;

-- ============================= funciones
CREATE OR REPLACE FUNCTION soloLetras(str VARCHAR2)
RETURN BOOLEAN
DETERMINISTIC
IS
BEGIN
    IF REGEXP_LIKE(str, '^[[:alpha:][:space:]\.ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½]*$') THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
CREATE OR REPLACE FUNCTION soloNumeros(num VARCHAR2)
RETURN BOOLEAN
DETERMINISTIC
IS
    isPositiveInteger BOOLEAN := FALSE;
BEGIN
    -- Verificar si el parametro es un numero entero positivo
    IF REGEXP_LIKE(num, '^[[:digit:]]+$') THEN
        isPositiveInteger := TRUE;
    END IF;

    RETURN isPositiveInteger;
END;
CREATE OR REPLACE FUNCTION validartipo(num VARCHAR2)
RETURN BOOLEAN
DETERMINISTIC
IS
BEGIN
    IF REGEXP_LIKE(num, '^[1-2]$') THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
CREATE OR REPLACE FUNCTION validarEmail(email IN VARCHAR2)
RETURN BOOLEAN
DETERMINISTIC
IS
BEGIN
    IF REGEXP_LIKE(email, '^[a-zA-Z0-9]+@[a-zA-Z]+(\.[a-zA-Z]+)+$') THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
CREATE OR REPLACE FUNCTION encrypt_password(
    p_password IN VARCHAR2,
    p_salt IN VARCHAR2 DEFAULT 'my_salt'
) RETURN VARCHAR2
AS
    v_encrypted_password VARCHAR2(200);
BEGIN
    -- Combinar la contraseï¿½a con la sal
    v_encrypted_password := DBMS_CRYPTO.ENCRYPT(
        src => UTL_RAW.CAST_TO_RAW(p_password || p_salt),
        typ => DBMS_CRYPTO.HASH_MD5
    );
    
    RETURN v_encrypted_password;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END encrypt_password;




-- ==================TRIGGERS
-- Tipo
CREATE OR REPLACE TRIGGER insert_tipocliente
AFTER INSERT ON tipocliente
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla tipocliente.', 'INSERT');
END;
CREATE OR REPLACE TRIGGER insert_tipotransaccion
AFTER INSERT ON tipotransaccion
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla tipotransaccion.', 'INSERT');
END;
CREATE OR REPLACE TRIGGER insert_tipocuenta
AFTER INSERT ON tipocuenta
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla tipocuenta.', 'INSERT');
END;
CREATE OR REPLACE TRIGGER insert_productoservicio
AFTER INSERT ON productoservicio
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla productoservicio.', 'INSERT');
END;
-- actualizaciones debito/deposito/compra
CREATE OR REPLACE TRIGGER trg_actualizar_saldo_cuenta
AFTER INSERT ON transaccion
FOR EACH ROW
BEGIN
    -- Registrar la transacciï¿½n en el historial
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, :NEW.otrosdetalles, 
            CASE 
                WHEN :NEW.codigotransaccion = 1 THEN 'Compra'
                WHEN :NEW.codigotransaccion = 2 THEN 'Depï¿½sito'
                WHEN :NEW.codigotransaccion = 3 THEN 'Dï¿½bito'
            END);
END;



-- Insertar datos
CREATE OR REPLACE TRIGGER insert_cliente
AFTER INSERT ON cliente
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla cliente.', 'INSERT');
END;
CREATE OR REPLACE TRIGGER insert_cuenta
AFTER INSERT ON cuenta
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla cuenta.', 'INSERT');
END;
CREATE OR REPLACE TRIGGER insert_compra
AFTER INSERT ON compra
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla compra.', 'INSERT');
END;
CREATE OR REPLACE TRIGGER insert_debito
AFTER INSERT ON debito
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla debito.', 'INSERT');
END;
CREATE OR REPLACE TRIGGER insert_deposito
AFTER INSERT ON deposito
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla deposito.', 'INSERT');
END;
CREATE OR REPLACE TRIGGER insert_transaccion
AFTER INSERT ON transaccion
FOR EACH ROW
BEGIN
    INSERT INTO historial_transacciones (fecha_hora, descripcion, tipo_operacion)
    VALUES (SYSTIMESTAMP, 'Se ha realizado una inserci?n en la tabla transaccion.', 'INSERT');
END;

-- =================-=-======================================== Consultas
CREATE OR REPLACE PROCEDURE consultarSaldoCliente(
    p_id_cuenta IN INTEGER
)
IS
    v_nombre_cliente VARCHAR2(100);
    v_tipo_cliente VARCHAR2(100);
    v_tipo_cuenta VARCHAR2(100);
    v_saldo_cuenta NUMBER(12, 2);
    v_saldo_apertura NUMBER(12, 2);
BEGIN
    -- Verificar si la cuenta existe
    SELECT c.nombre, tc.nombre, tpc.nombre, cu.saldo_cuenta, cu.monto_apertura
    INTO v_nombre_cliente, v_tipo_cliente, v_tipo_cuenta, v_saldo_cuenta, v_saldo_apertura
    FROM cuenta cu
    INNER JOIN cliente c ON cu.idcliente = c.idcliente
    INNER JOIN tipocliente tc ON c.idtipo = tc.idtipo
    INNER JOIN tipocuenta tpc ON cu.tipo_cuenta = tpc.codigo
    WHERE cu.id_cuenta = p_id_cuenta;

    -- Si la cuenta existe, imprimir la informaci?n
    DBMS_OUTPUT.PUT_LINE('Nombre Cliente: ' || v_nombre_cliente);
    DBMS_OUTPUT.PUT_LINE('Tipo de cliente: ' || v_tipo_cliente);
    DBMS_OUTPUT.PUT_LINE('Tipo de cuenta: ' || v_tipo_cuenta);
    DBMS_OUTPUT.PUT_LINE('Saldo cuenta: ' || TO_CHAR(v_saldo_cuenta, '999999999.99'));
    DBMS_OUTPUT.PUT_LINE('Saldo apertura: ' || TO_CHAR(v_saldo_apertura, '999999999.99'));
EXCEPTION
    -- Si la cuenta no existe, manejar la excepci?n
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No existe la cuenta');
END;
BEGIN  consultarSaldoCliente(3030206080);
END;
CREATE OR REPLACE PROCEDURE consultarCliente(
    p_idCliente IN INTEGER
)
AS
    v_nombre_cliente VARCHAR2(100);
    v_fecha_creacion DATE;
    v_usuario VARCHAR2(40);
    v_telefonos VARCHAR2(500);
    v_correos VARCHAR2(500);
    v_num_cuentas INTEGER;
    v_tipos_cuenta VARCHAR2(500);
BEGIN
    -- Verificar si el cliente existe
    SELECT c.nombre || ' ' || c.apellidos, c.historial, c.usuario
    INTO v_nombre_cliente, v_fecha_creacion, v_usuario
    FROM cliente c
    WHERE c.idcliente = p_idCliente;

    -- Obtener los tel?fonos del cliente
    SELECT LISTAGG(telefono, ', ') WITHIN GROUP (ORDER BY id_telefono)
    INTO v_telefonos
    FROM telefono
    WHERE idcliente = p_idCliente;

    -- Obtener los correos del cliente
    SELECT LISTAGG(correo, ', ') WITHIN GROUP (ORDER BY id_correo)
    INTO v_correos
    FROM correo
    WHERE idcliente = p_idCliente;

    -- Contar el n?mero de cuentas del cliente
    SELECT COUNT(*)
    INTO v_num_cuentas
    FROM cuenta
    WHERE idcliente = p_idCliente;

    -- Obtener los tipos de cuenta del cliente
    SELECT LISTAGG(tc.nombre, ', ') WITHIN GROUP (ORDER BY cu.tipo_cuenta)
    INTO v_tipos_cuenta
    FROM cuenta cu
    INNER JOIN tipocuenta tc ON cu.tipo_cuenta = tc.codigo
    WHERE cu.idcliente = p_idCliente;

    -- Construir el resultado
    DBMS_OUTPUT.PUT_LINE('Id cliente: ' || p_idCliente);
    DBMS_OUTPUT.PUT_LINE('Nombre completo: ' || v_nombre_cliente);
    DBMS_OUTPUT.PUT_LINE('Fecha de creacion: ' || TO_CHAR(v_fecha_creacion, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('Usuario: ' || v_usuario);
    DBMS_OUTPUT.PUT_LINE('Telefono(s): ' || v_telefonos);
    DBMS_OUTPUT.PUT_LINE('Correo(s): ' || v_correos);
    DBMS_OUTPUT.PUT_LINE('No cuenta(s) que posee: ' || v_num_cuentas);
    DBMS_OUTPUT.PUT_LINE('Tipo(s) de cuenta que posee: ' || v_tipos_cuenta);
EXCEPTION
    -- Si el cliente no existe, manejar la excepci?n
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('El cliente con ID ' || p_idCliente || ' no existe');
END;
EXEC consultarCliente(1001);
CREATE OR REPLACE PROCEDURE consultarDesasignacion
IS
BEGIN
  -- Consultar los productos y servicios
  FOR r IN (SELECT cod_ps, descripcion, costo, tipo
            FROM productoservicio)
  LOOP
    -- Mostrar la informaci?n de cada producto/servicio
    DBMS_OUTPUT.PUT_LINE('Codigo: ' || r.cod_ps);
    DBMS_OUTPUT.PUT_LINE('Nombre: ' || r.descripcion);
    DBMS_OUTPUT.PUT_LINE('Descripcion: ' || r.descripcion);
    DBMS_OUTPUT.PUT_LINE('Tipo: ' || r.tipo);
    DBMS_OUTPUT.PUT_LINE('');
  END LOOP;
END;
BEGIN  consultarDesasignacion;
END;
CREATE OR REPLACE PROCEDURE consultarMovsCliente (
    idCliente IN INTEGER
) AS
    -- Declarar cursor para los movimientos del cliente
    CURSOR mov_cursor IS
        SELECT 
            t.id_transaccion AS "Id transaccion",
            tt.nombre AS "Tipo transaccion",
            CASE
                WHEN t.id_compra IS NOT NULL THEN 'Compra'
                WHEN t.id_debito IS NOT NULL THEN 'Débito'
                WHEN t.id_deposito IS NOT NULL THEN 'Deposito'
                ELSE 'Otro'
            END AS "Tipo servicio",
            t.fecha AS "Fecha",
            t.otrosdetalles AS "Descripcion",
            t.id_cuenta AS "No. cuenta",
            tc.nombre AS "Tipo cuenta",
            c.monto_apertura AS "Monto"
        FROM 
            transaccion t
        INNER JOIN cuenta c ON t.id_cuenta = c.id_cuenta
        INNER JOIN tipotransaccion tt ON t.codigotransaccion = tt.codigotransaccion
        INNER JOIN tipocuenta tc ON c.tipo_cuenta = tc.codigo
        WHERE 
            c.idcliente = idCliente;

    -- Declarar variable para almacenar los datos del movimiento
    mov_rec mov_cursor%ROWTYPE;
BEGIN
    -- Abrir cursor
    OPEN mov_cursor;

    -- Recorrer el cursor y mostrar los resultados
    LOOP
        FETCH mov_cursor INTO mov_rec;
        EXIT WHEN mov_cursor%NOTFOUND;
        
        -- Imprimir los resultados
        DBMS_OUTPUT.PUT_LINE('Id transaccion: ' || mov_rec."Id transaccion");
        DBMS_OUTPUT.PUT_LINE('Tipo transaccion: ' || mov_rec."Tipo transaccion");
        DBMS_OUTPUT.PUT_LINE('Tipo servicio: ' || mov_rec."Tipo servicio");
        DBMS_OUTPUT.PUT_LINE('Fecha: ' || mov_rec."Fecha");
        DBMS_OUTPUT.PUT_LINE('Descripcion: ' || mov_rec."Descripcion");
        DBMS_OUTPUT.PUT_LINE('No. cuenta: ' || mov_rec."No. cuenta");
        DBMS_OUTPUT.PUT_LINE('Tipo cuenta: ' || mov_rec."Tipo cuenta");
        DBMS_OUTPUT.PUT_LINE('Monto: ' || mov_rec."Monto");
        DBMS_OUTPUT.PUT_LINE('------------------------');
    END LOOP;

    -- Cerrar cursor
    CLOSE mov_cursor;
END;
BEGIN    consultarMovsCliente(3030206080);
END;
CREATE OR REPLACE PROCEDURE consultarTipoCuentas (
    idTipoCuenta IN INTEGER
) AS
BEGIN
    -- Verificar si el tipo de cuenta ingresado existe
    DECLARE
        tipo_cuenta_count INTEGER;
    BEGIN
        SELECT COUNT(*)
        INTO tipo_cuenta_count
        FROM tipocuenta
        WHERE codigo = idTipoCuenta;

        IF tipo_cuenta_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Error: El tipo de cuenta ingresado no existe.');
            RETURN;
        END IF;
    END;

    -- Consultar clientes que tienen el tipo de cuenta ingresado
    FOR cliente_rec IN (
        SELECT c.idcliente, c.nombre, c.apellidos
        FROM cliente c
        INNER JOIN cuenta cu ON c.idcliente = cu.idcliente
        WHERE cu.tipo_cuenta = idTipoCuenta
    )
    LOOP
        -- Mostrar informacion del cliente
        DBMS_OUTPUT.PUT_LINE('Codigo de cliente: ' || cliente_rec.idcliente);
        DBMS_OUTPUT.PUT_LINE('Nombre: ' || cliente_rec.nombre);
        DBMS_OUTPUT.PUT_LINE('Apellidos: ' || cliente_rec.apellidos);
        DBMS_OUTPUT.PUT_LINE('------------------------');
    END LOOP;
END;
BEGIN    consultarTipoCuentas(5);
END;
CREATE OR REPLACE PROCEDURE consultarMovsGenFech (
    fechaInicioStr IN VARCHAR2,
    fechaFinStr IN VARCHAR2
) AS
    fechaInicio DATE;
    fechaFin DATE;
BEGIN
    -- Convertir las cadenas de fecha a objetos de fecha
    fechaInicio := TO_DATE(fechaInicioStr, 'DD-MM-YYYY');
    fechaFin := TO_DATE(fechaFinStr, 'DD-MM-YYYY');
    
    -- Verificar si las fechas son vï¿½lidas
    IF fechaInicio IS NULL OR fechaFin IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Error: Las fechas de inicio y fin son obligatorias.');
        RETURN;
    END IF;

    -- Consultar movimientos generales por rango de fechas
    FOR mov_rec IN (
        SELECT 
            t.id_transaccion AS "Id transaccion",
            tt.nombre AS "Tipo transaccion",
            CASE
                WHEN t.id_compra IS NOT NULL THEN 'Compra'
                WHEN t.id_debito IS NOT NULL THEN 'Dï¿½bito'
                WHEN t.id_deposito IS NOT NULL THEN 'Deposito'
                ELSE 'Otro'
            END AS "Tipo servicio",
            c.nombre AS "Nombre Cliente",
            cu.id_cuenta AS "No. cuenta",
            tc.nombre AS "Tipo de cuenta",
            t.fecha AS "Fecha",
            t.otrosdetalles AS "Otros detalle"
        FROM 
            transaccion t
        INNER JOIN cuenta cu ON t.id_cuenta = cu.id_cuenta
        INNER JOIN cliente c ON cu.idcliente = c.idcliente
        INNER JOIN tipotransaccion tt ON t.codigotransaccion = tt.codigotransaccion
        INNER JOIN tipocuenta tc ON cu.tipo_cuenta = tc.codigo
        WHERE 
            t.fecha BETWEEN fechaInicio AND fechaFin
    )
    LOOP
        -- Mostrar informacion del movimiento
        DBMS_OUTPUT.PUT_LINE('Id transaccion: ' || mov_rec."Id transaccion");
        DBMS_OUTPUT.PUT_LINE('Tipo transaccion: ' || mov_rec."Tipo transaccion");
        DBMS_OUTPUT.PUT_LINE('Tipo servicio: ' || mov_rec."Tipo servicio");
        DBMS_OUTPUT.PUT_LINE('Nombre Cliente: ' || mov_rec."Nombre Cliente");
        DBMS_OUTPUT.PUT_LINE('No. cuenta: ' || mov_rec."No. cuenta");
        DBMS_OUTPUT.PUT_LINE('Tipo de cuenta: ' || mov_rec."Tipo de cuenta");
        DBMS_OUTPUT.PUT_LINE('Fecha: ' || mov_rec."Fecha");
        DBMS_OUTPUT.PUT_LINE('Otros detalle: ' || mov_rec."Otros detalle");
        DBMS_OUTPUT.PUT_LINE('------------------------');
    END LOOP;
END;
EXEC consultarMovsGenFech('01-04-2024', '30-04-2024');

CREATE OR REPLACE PROCEDURE consultarMovsFechClien (
    cliente_id IN NUMBER,
    fecha_inicio IN VARCHAR2,
    fecha_final IN VARCHAR2
) AS
    cliente_existente NUMBER;
    fecha_inicio_valida DATE;
    fecha_final_valida DATE;
BEGIN
    -- Verificar si el cliente existe
    SELECT COUNT(*) INTO cliente_existente FROM cliente WHERE idcliente = cliente_id;
    IF cliente_existente = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: El ID de cliente especificado no existe.');
        RETURN;
    END IF;

    -- Convertir las fechas a formato DATE
    fecha_inicio_valida := TO_DATE(fecha_inicio, 'DD/MM/YYYY');
    fecha_final_valida := TO_DATE(fecha_final, 'DD/MM/YYYY');

    -- Realizar la consulta de movimientos financieros
    for mov_rec In(
       SELECT
            t.id_transaccion AS "Id transacción",
            tt.nombre AS "Tipo transacción",
            CASE
                WHEN t.id_compra IS NOT NULL THEN 'Compra'
                WHEN t.id_debito IS NOT NULL THEN 'Débito'
                WHEN t.id_deposito IS NOT NULL THEN 'Depósito'
                ELSE 'N/A'
            END AS "Tipo de servicio",
            c.nombre AS "Nombre Cliente",
            cu.id_cuenta AS "No cuenta",
            tc.nombre AS "Tipo de cuenta",
            t.fecha AS "Fecha",
            CASE
                WHEN t.id_compra IS NOT NULL THEN co.importe_compra
                WHEN t.id_debito IS NOT NULL THEN d.monto
                WHEN t.id_deposito IS NOT NULL THEN de.monto
                ELSE NULL
            END AS "Monto",
            t.otrosdetalles AS "Otros detalles"
        FROM
            transaccion t
        INNER JOIN
            cuenta cu ON t.id_cuenta = cu.id_cuenta
        INNER JOIN
            cliente c ON cu.idcliente = c.idcliente
        INNER JOIN
            tipotransaccion tt ON t.codigotransaccion = tt.codigotransaccion
        INNER JOIN
            tipocuenta tc ON cu.tipo_cuenta = tc.codigo
        LEFT JOIN
            compra co ON t.id_compra = co.id_compra
        LEFT JOIN
            debito d ON t.id_debito = d.id_debito
        LEFT JOIN
            deposito de ON t.id_deposito = de.id_deposito
        WHERE
            c.idcliente = cliente_id
            AND t.fecha BETWEEN fecha_inicio_valida AND fecha_final_valida
    ) loop
        -- Mostrar informacion del movimiento
        DBMS_OUTPUT.PUT_LINE('Id transacción: ' || mov_rec."Id transacción");
        DBMS_OUTPUT.PUT_LINE('Tipo transacción: ' || mov_rec."Tipo transacción");
        DBMS_OUTPUT.PUT_LINE('Tipo de servicio: ' || mov_rec."Tipo de servicio");
        DBMS_OUTPUT.PUT_LINE('Nombre Cliente: ' || mov_rec."Nombre Cliente");
        DBMS_OUTPUT.PUT_LINE('No. cuenta: ' || mov_rec."No cuenta");
        DBMS_OUTPUT.PUT_LINE('Tipo de cuenta: ' || mov_rec."Tipo de cuenta");
        DBMS_OUTPUT.PUT_LINE('Fecha: ' || mov_rec."Fecha");
        DBMS_OUTPUT.PUT_LINE('Monto: ' || mov_rec."Monto");
        DBMS_OUTPUT.PUT_LINE('Otros detalles: ' || mov_rec."Otros detalles");
        DBMS_OUTPUT.PUT_LINE('------------------------');
    end loop;
END;
EXEC consultarMovsFechClien (1001, '01-04-2024', '30-04-2024');

-- DATOS A INSERTAR tipos
-- Tipo de datps
begin
registrarTipoCliente(1, 'Individual Nacional', 'Este tipo de cliente es una persona individual de nacionalidad guatemalteca.');
registrarTipoCliente(2, 'Individual Extranjero', 'Este tipo de cliente es una persona individual de nacionalidad extranjera.');
registrarTipoCliente(3, 'Empresa PyMe','Este tipo de cliente es una empresa de tipo peque?a o mediana');
registrarTipoCliente(4, 'Empresa S.C','Este tipo de cliente corresponde a las empresa grandes que tienen una sociedad colectiva.');
--tipo transaccion
registrarTipoTransaccion(1, 'Compra', 'Transacci?n de compra');
registrarTipoTransaccion(2, 'Deposito', 'Transacci?n de deposito');
registrarTipoTransaccion(3, 'Debito', 'Transacci?n de debito');
-- tipo cuenta
    registrarTipoCuenta(1,'Cuenta de Cheques','Este tipo de cuenta ofrece la facilidad de emitir cheques para realizar transacciones monetarias.');
    registrarTipoCuenta(2, 'Cuenta de Ahorro', 'Esta cuenta genera un inter?s anual del 2%, lo que la hace ideal para guardar fondos a largo plazo.');
    registrarTipoCuenta(3, 'Cuenta de Ahorro Plus','Con una tasa de inter?s anual del 10%, esta cuenta de ahorros ofrece mayores rendimientos.');
    registrarTipoCuenta(4, 'Peque?a Cuenta', 'Una cuenta de ahorros con un inter?s semestral del 0.5%, ideal para peque?os ahorros y movimientos.');    
    registrarTipoCuenta(5, 'Cuenta de N?mina','Dise?ada para recibir dep?sitos de sueldo y realizar pagos, con acceso a servicios bancarios b?sicos');
    registrarTipoCuenta(6, 'Cuenta de Inversi?n','Orientada a inversionistas, ofrece opciones de inversi?n y rendimientos m?s altos que una cuenta de ahorros est?ndar.');
    registrarTipoCuenta(7,'Cuenta Extraordinaria','Cuenta Extraordinaria a enunciado');
-- Productos y servicios
-- registro de productoservicio
--                    id, tipo, costo, descripcion
crearProductoServicio(1, 1, 10, 'Servicio de tarjeta de debito'); 
crearProductoServicio(2, 1, 10, 'Servicio de chequera');
crearProductoServicio(3, 1, 400, 'Servicio de asesoramiento financiero');
crearProductoServicio(4, 1, 5, 'Servicio de banca personal'); 
crearProductoServicio(5, 1, 30, 'Seguro de vida'); 
crearProductoServicio(6, 1, 100, 'Seguro de vida plus');
crearProductoServicio(7, 1, 300, 'Seguro de autom?vil'); 
crearProductoServicio(8, 1, 500, 'Seguro de autom?vil plus'); 
crearProductoServicio(9, 1, 0.05, 'Servicio de deposito'); 
crearProductoServicio(10, 1, 0.10, 'Servicio de Debito'); 
crearProductoServicio(11, 2, 0, 'Pago de energ?a El?ctrica (EEGSA)'); 
crearProductoServicio(12, 2, 0, 'Pago de agua potable (Empagua)'); 
crearProductoServicio(13, 2, 0, 'Pago de Matricula USAC'); 
crearProductoServicio(14, 2, 0, 'Pago de curso vacaciones USAC'); 
crearProductoServicio(15, 2, 0, 'Pago de servicio de internet'); 
crearProductoServicio(16, 2, 0, 'Servicio de suscripci?n plataformas streaming'); 
crearProductoServicio(17, 2, 0, 'Servicios Cloud'); 
crearProductoServicio(18, 1, 50.80, 'Este es un servicio el cual tiene un precio predefinido'); --servicio
crearProductoServicio(19, 2, 0, 'Este es un producto el cual tiene un precio variable'); --producto, tiene un precio de "cero" el cual indica que es variable

end;
-- cliente
begin
registrarCliente(1001, 'Juan Isaac','Perez Lopez','22888080','micorreo@gmail.com','jisaacp2024','12345678','1' );
registrarCliente(1002, 'Maria Isabel','Gonzalez Perez','22805050-22808080','micorreo1@gmail.com|micorreo2@gmail.com','mariauser','12345679','2' );
registrarCliente(1003, 'Maria Isabel','Gonzalez Perez','22805053','micorreo21@gmail.com','jisaacp2024','12345679','2' );
end;

--retiro
begin
-- realizar retiro
--              id,      fecha,     monto,  otrosdetalles, idcliente
realizarDebito(1116, '10/04/2024', 100, 'retiro de dinero', 1001);
realizarDebito(1117, '10/04/2024', 0, 'retiro de dinero con error', 1001); --aqui hay error ya que el monto deberia de ser mayor a cero
end;
-- realizar deposito
begin
--              id,      fecha,     monto,  otrosdetalles, idcliente
realizarDeposito(1114, '10/04/2024', 100, 'deposito de dinero', 1001);
realizarDeposito(1115, '10/04/2024', 0, 'deposito de dinero', 1001); --aqui hay error ya que el monto deberia de ser mayor a cero
end;
-- realizr compra
begin
realizarCompra(1111, '10/04/2024', 40, 'compra de servicio', 18, 1001); --aqui hay error ya que el monto deberia de ser cero por que ya tiene un precio preestablecido por ser un servicio
realizarCompra(1112, '10/04/2024', 0, 'compra de producto', 19, 1001); --aqui hay error debido a que el monto deberia de ser > 0 ya que es un producto y no tiene un precio preestablecido
realizarCompra(1113, '10/04/2024', 50, 'compra de producto', 19, 1001); --aqui esta correcto ya que el monto es mayor a cero y es un producto
end;
-- registrar cuenta
begin
    registrarCuenta(3030206080, 500.00, 800.00, 'Apertura de cuenta con Q500',NULL ,NULL ,5,1001);
    registrarCuenta(3030206081, 600.00, 600.00, 'Apertura de cuenta con Q500','01/04/2024 07:00:00','esta apertura tiene fecha',5,1001);
end;


--transaccion
begin
-- registrar transaccion
--              id,      fecha,  otrosdetalles, id_tipo_transaccion, idcompra/deposito/debito, nocuenta
registrarTransaccion(1118, '10/04/2024','', 1, 1113, 3030206080); -- aqui hay error debido a que no se tiene el saldo suficiente para realizar la compra
registrarTransaccion(1115, '10/04/2024','',2, 1114, 3030206080); -- se realia deposito *aqui se puede depositar a una cuenta que no es del cliente
registrarTransaccion(1120, '10/04/2024','este si tiene detalle',3,  1116, 3030206080); -- se realiza un debito
end;


-- Eliminar datos almacenados
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



CREATE TABLE tipocliente (
    idtipo      INTEGER NOT NULL PRIMARY KEY,
    nombre      VARCHAR2(40) NOT NULL,
    descripcion VARCHAR2(200)
);
CREATE TABLE tipotransaccion (
    codigotransaccion INTEGER NOT NULL PRIMARY KEY,
    nombre            VARCHAR2(40),
    descripcion       VARCHAR2(200)
);
CREATE TABLE cliente (
    idcliente  INTEGER NOT NULL PRIMARY KEY,
    nombre     VARCHAR2(40) NOT NULL,
    apellidos  VARCHAR2(40),
    usuario    VARCHAR2(40) NOT NULL,
    contrasena VARCHAR2(200) NOT NULL,
    idtipo     INTEGER NOT NULL,
    historial date,
    CONSTRAINT cliente_tipo_fk FOREIGN KEY (idtipo) REFERENCES tipocliente(idtipo)
);
CREATE TABLE correo (
    id_correo   INTEGER NOT NULL PRIMARY KEY,
    idcliente   INTEGER NOT NULL,
    correo      VARCHAR2(150) NOT NULL,
    CONSTRAINT correo_cliente_fk FOREIGN KEY (idcliente) REFERENCES cliente(idcliente)
);
CREATE SEQUENCE correo_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE telefono (
    id_telefono INTEGER NOT NULL PRIMARY KEY,
    idcliente   INTEGER NOT NULL,
    telefono    VARCHAR2(12) NOT NULL,
    CONSTRAINT telefono_cliente_fk FOREIGN KEY (idcliente) REFERENCES cliente(idcliente)
);
CREATE SEQUENCE telefono_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE tipocuenta (
    codigo      INTEGER NOT NULL PRIMARY KEY,
    nombre      VARCHAR2(40),
    descripcion VARCHAR2(200)
);
CREATE TABLE cuenta (
    id_cuenta          INTEGER NOT NULL PRIMARY KEY,
    monto_apertura     NUMBER(12, 2),
    saldo_cuenta       NUMBER(12, 2) NOT NULL,
    descripcion        VARCHAR2(200),
    fecha_de_apertura  DATE,
    otros_detalles     VARCHAR2(200),
    tipo_cuenta        INTEGER,
    idcliente          INTEGER,
    CONSTRAINT cuenta_cliente_fk FOREIGN KEY (idcliente) REFERENCES cliente(idcliente),
    CONSTRAINT cuenta_tipocuenta_fk FOREIGN KEY (tipo_cuenta) REFERENCES tipocuenta(codigo)
);
CREATE TABLE productoservicio (
    cod_ps      INTEGER NOT NULL PRIMARY KEY,
    tipo        INTEGER NOT NULL,
    costo       NUMBER(12, 2) NOT NULL,
    descripcion VARCHAR2(200)
);
CREATE TABLE debito (
    id_debito      INTEGER NOT NULL PRIMARY KEY,
    fecha          DATE,
    monto          NUMBER(12, 2) NOT NULL,
    otros_detalles VARCHAR2(200),
    idcliente      INTEGER,
    CONSTRAINT debito_cliente_fk FOREIGN KEY (idcliente) REFERENCES cliente(idcliente)
);
CREATE TABLE compra (
    id_compra      INTEGER NOT NULL PRIMARY KEY,
    fecha          DATE,
    importe_compra NUMBER(12, 2) NOT NULL,
    otros_detalles VARCHAR2(200),
    idcliente      INTEGER,
    cod_ps         INTEGER,
    CONSTRAINT compra_cliente_fk FOREIGN KEY (idcliente) REFERENCES cliente(idcliente),
    CONSTRAINT compra_productoservicio_fk FOREIGN KEY (cod_ps) REFERENCES productoservicio(cod_ps)
);
CREATE TABLE deposito (
    id_deposito    INTEGER NOT NULL PRIMARY KEY,
    fecha          DATE,
    monto          NUMBER(12, 2),
    otros_detalles VARCHAR2(200),
    idcliente      INTEGER,
    CONSTRAINT deposito_cliente_fk FOREIGN KEY (idcliente) REFERENCES cliente(idcliente)
);
CREATE TABLE transaccion (
    id_transaccion    INTEGER NOT NULL PRIMARY KEY,
    fecha             DATE,
    otrosdetalles     VARCHAR2(200),
    id_cuenta         INTEGER,
    codigotransaccion INTEGER,
    id_debito         INTEGER,
    id_deposito       INTEGER,
    id_compra         INTEGER,
    CONSTRAINT transaccion_cuenta_fk FOREIGN KEY (id_cuenta) REFERENCES cuenta(id_cuenta),
    CONSTRAINT transaccion_tipotransaccion_fk FOREIGN KEY (codigotransaccion) REFERENCES tipotransaccion(codigotransaccion),
    CONSTRAINT transaccion_debito_fk FOREIGN KEY (id_debito) REFERENCES debito(id_debito),
    CONSTRAINT transaccion_deposito_fk FOREIGN KEY (id_deposito) REFERENCES deposito(id_deposito),
    CONSTRAINT transaccion_compra_fk FOREIGN KEY (id_compra) REFERENCES compra(id_compra)
);
CREATE TABLE historial_transacciones (
    fecha_hora TIMESTAMP,
    descripcion VARCHAR2(200),
    tipo_operacion VARCHAR2(10)
);




DROP TABLE historial_transacciones;
DROP TABLE transaccion;
DROP TABLE cuenta;
DROP TABLE debito;
DROP TABLE deposito;
DROP TABLE compra;  -- Esta tabla es referenciada por productoservicio
DROP TABLE productoservicio;  -- Esta tabla es referenciada por compra
DROP TABLE correo;
DROP TABLE telefono;
DROP TABLE cliente;
DROP TABLE tipocliente;
DROP TABLE tipotransaccion;
DROP TABLE tipocuenta;
-- Eliminacion de secuencias
DROP SEQUENCE correo_seq;
DROP SEQUENCE telefono_seq;
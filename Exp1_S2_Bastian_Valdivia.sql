/* =====================================================================
   PRY2206 - SUMATIVA SEMANA 2
   SCRIPT COMPLETO - TODO EN UN SOLO ARCHIVO

   ¿QUÉ HACE ESTE SCRIPT?
   - Crea un usuario en Oracle
   - Genera nombres de usuario y claves automáticamente
   - Valida que todo funcione correctamente

   ¿CÓMO USARLO?  *****(USAR Oracle XE)******
   - Primera parte: ejecutar como SYSTEM
   - Resto: ejecutar como SUMATIVA_2206_P1
   ===================================================================== */


/* =====================================================================
   PARTE A - CREAR USUARIO Y PREPARAR TODO
   ===================================================================== */

/* ---------------------------------------------------------------------
   ESTA PARTE SE EJECUTA COMO SYSTEM (el administrador)
   --------------------------------------------------------------------- */

/* Paso 1: Ver en qué base de datos estamos */
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS con_name
FROM   dual;


/* Paso 2: Borrar el usuario si ya existe (para empezar limpio) */
BEGIN
    EXECUTE IMMEDIATE 'DROP USER SUMATIVA_2206_P1 CASCADE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1918 THEN
            NULL; -- El usuario no existía, está bien
        ELSE
            RAISE; -- Hay otro error, mostrarlo
        END IF;
END;
/

/* Paso 3: Crear el usuario nuevo */
CREATE USER SUMATIVA_2206_P1 IDENTIFIED BY "PRY2206.sumativa_1"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP;

/* Paso 4: Activar la cuenta y darle espacio */
ALTER USER SUMATIVA_2206_P1 ACCOUNT UNLOCK;
ALTER USER SUMATIVA_2206_P1 QUOTA UNLIMITED ON USERS;

/* Paso 5: Darle permisos para trabajar */
GRANT CREATE SESSION   TO SUMATIVA_2206_P1;  -- Puede conectarse
GRANT CREATE TABLE     TO SUMATIVA_2206_P1;  -- Puede crear tablas
GRANT CREATE SEQUENCE  TO SUMATIVA_2206_P1;  -- Puede crear secuencias
GRANT CREATE VIEW      TO SUMATIVA_2206_P1;  -- Puede crear vistas
GRANT CREATE PROCEDURE TO SUMATIVA_2206_P1;  -- Puede crear procedimientos
GRANT CREATE TRIGGER   TO SUMATIVA_2206_P1;  -- Puede crear triggers

/* Paso 6: Verificar que el usuario se creó bien */
SELECT username, 
       account_status, 
       default_tablespace
FROM   dba_users
WHERE  username = 'SUMATIVA_2206_P1';

/* ==========================================================
   ¡LISTO! Ahora desconéctate de SYSTEM
   
   SIGUIENTE PASO:
   Conéctate como SUMATIVA_2206_P1 y sigue ejecutando abajo
   ========================================================== */












/* ---------------------------------------------------------------------
   AHORA EJECUTA ESTA PARTE COMO SUMATIVA_2206_P1
   --------------------------------------------------------------------- */

/* Paso 1: Confirmar que estás con el usuario correcto */
SELECT USER                               AS usuario_actual,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor_actual
FROM   dual;

/* Paso 2: Configurar el formato de fechas */
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';










/* ---------------------------------------------------------------------
   Paso 3: IMPORTANTE - HACER ESTO MANUALMENTE
   
   1. Abre el archivo de la actividad (el que tiene las tablas y datos)
   2. Ejecútalo con F5
   3. Vuelve aquí y continúa
   
   NOTA SOBRE EL PARCHE APLICADO AL SCRIPT DE LA ACTIVIDAD:
   Se agregaron dos líneas para evitar errores de formato de fecha:
   
   - ANTES de los INSERT INTO empleado:
     ALTER SESSION SET NLS_DATE_FORMAT = 'DDMMYYYY';
   
   - DESPUÉS de los INSERT INTO empleado:
     ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';
   
   Esto corrige el problema de mezcla de formatos de fecha
   (algunos INSERT usan DDMMYYYY y otros DD/MM/YYYY)
   --------------------------------------------------------------------- */










/* Paso 4: Ver qué tablas se crearon */
SELECT table_name
FROM   user_tables
ORDER BY table_name;

/* Paso 5: Contar cuántos empleados hay */
SELECT COUNT(*)    AS total_empleados,
       MIN(id_emp) AS min_id_emp,
       MAX(id_emp) AS max_id_emp
FROM   empleado;

/* Paso 6: Ver algunos empleados de ejemplo */
SELECT e.id_emp,
       e.numrun_emp,
       e.dvrun_emp,
       e.pnombre_emp,
       e.appaterno_emp,
       e.fecha_nac,
       e.fecha_contrato,
       e.sueldo_base,
       ec.nombre_estado_civil
FROM   empleado e
       JOIN estado_civil ec ON ec.id_estado_civil = e.id_estado_civil
ORDER BY e.id_emp
FETCH FIRST 10 ROWS ONLY;

/* Paso 7: Verificar que existe la tabla donde guardaremos los resultados */
SELECT COUNT(*) AS filas_usuario_clave
FROM   usuario_clave;

/* ==========================================================
   Si todo está bien, continúa con la PARTE B
   ========================================================== */













/* =====================================================================
   PARTE B - DEFINIR LA FECHA PARA LOS CÁLCULOS (PARAMÉTRICO CON BIND)
   
   IMPORTANTE: Uso de BIND VARIABLE
   - La bind variable permite que el proceso sea PARAMÉTRICO
   - Se puede cambiar la fecha sin modificar el código del bloque PL/SQL
   - Esto cumple con el requisito de "fecha de proceso paramétrica"
   =================================================================== */

/* BIND VARIABLE: Declaración de la variable de sustitución */
VAR b_fecha_proceso VARCHAR2(10);

/* BIND VARIABLE: Asignación del valor (usa fecha actual del sistema) */
BEGIN
    /* 
       NOTA SOBRE PARAMETRIZACIÓN:
       - Por defecto usa SYSDATE (fecha actual del sistema)
       - Puedes cambiar esta línea para usar cualquier fecha
       - El bloque PL/SQL principal usa :b_fecha_proceso en todos sus cálculos
       - Esto hace que el proceso sea completamente paramétrico
    */
    :b_fecha_proceso := TO_CHAR(SYSDATE, 'DD/MM/YYYY');
    
    /* Ejemplo para usar una fecha específica (descomentar si necesitas):
    :b_fecha_proceso := '15/01/2026';
    */
END;
/

/* EVIDENCIA: Mostrar el valor de la BIND VARIABLE antes de usarla */
PRINT b_fecha_proceso;












/* =====================================================================
   PARTES C/D - EL PROGRAMA PRINCIPAL
   
   CARACTERÍSTICAS IMPLEMENTADAS:
   
   1. USO DE BIND VARIABLE:
      - Se usa :b_fecha_proceso para la fecha de proceso
      - Permite cambiar la fecha sin modificar el código
      
   2. SQL DINÁMICO:
      - EXECUTE IMMEDIATE para TRUNCATE TABLE
      
   3. ITERACIÓN REQUERIDA:
      - FOR loop de 100 a 320
      
   4. VARIABLES %TYPE:
      - Se usan más de 3 variables tipadas con %TYPE
      
   5. REGLAS DE NEGOCIO EN PL/SQL:
      - Construcción de nombre_usuario en código
      - Construcción de clave_usuario en código
      - Función interna para letras del apellido
      
   6. CONTROL TRANSACCIONAL:
      - COMMIT solo si el proceso completó exitosamente
      - ROLLBACK automático si falla
   ===================================================================== */

DECLARE
    /* ================================================================
       VARIABLES DE CONTROL DEL PROCESO
       ================================================================ */
    
    /* Fecha de proceso: se toma de la BIND VARIABLE :b_fecha_proceso
       Esto hace que el proceso sea PARAMÉTRICO */
    v_fecha_proceso   DATE;
    
    /* Control transaccional: para validar que se procesaron todos */
    v_total_esperado  PLS_INTEGER := 0;
    v_total_procesado PLS_INTEGER := 0;

    /* ================================================================
       VARIABLES TIPADAS CON %TYPE (requisito: usar al menos 3)
       Se usan 9 variables %TYPE
       ================================================================ */
    v_id_emp         empleado.id_emp%TYPE;
    v_numrun         empleado.numrun_emp%TYPE;
    v_dvrun          empleado.dvrun_emp%TYPE;
    v_pnombre        empleado.pnombre_emp%TYPE;
    v_appaterno      empleado.appaterno_emp%TYPE;
    v_fecha_nac      empleado.fecha_nac%TYPE;
    v_fecha_contrato empleado.fecha_contrato%TYPE;
    v_sueldo_base    empleado.sueldo_base%TYPE;
    v_estado_civil   estado_civil.nombre_estado_civil%TYPE;

    /* Variables para los resultados finales (tipadas desde tabla destino) */
    v_nombre_empleado usuario_clave.nombre_empleado%TYPE;
    v_nombre_usuario  usuario_clave.nombre_usuario%TYPE;
    v_clave_usuario   usuario_clave.clave_usuario%TYPE;

    /* ================================================================
       VARIABLES AUXILIARES PARA CONSTRUIR NOMBRE_USUARIO
       Estas variables implementan las reglas de negocio en PL/SQL
       ================================================================ */
    v_letra_ec          VARCHAR2(1);    -- Primera letra estado civil
    v_3letras_nombre    VARCHAR2(3);    -- Tres primeras letras del nombre
    v_largo_nombre      PLS_INTEGER;    -- Longitud del nombre
    v_ultimo_dig_sueldo VARCHAR2(1);    -- Último dígito del sueldo
    v_anios_trabajados  PLS_INTEGER;    -- Años trabajados (cálculo en PL/SQL)

    /* ================================================================
       VARIABLES AUXILIARES PARA CONSTRUIR CLAVE_USUARIO
       Estas variables implementan las reglas de negocio en PL/SQL
       ================================================================ */
    v_tercer_dig_run     VARCHAR2(1);   -- Tercer dígito del RUN
    v_anio_nac_mas2      PLS_INTEGER;   -- Año nacimiento + 2
    v_ult3_sueldo_menos1 PLS_INTEGER;   -- Últimos 3 dígitos sueldo - 1
    v_letras_apellido    VARCHAR2(2);   -- Letras apellido según estado civil
    v_mmyyyy             VARCHAR2(6);   -- Mes y año proceso (MMYYYY)

    /* ================================================================
       FUNCIÓN INTERNA: Obtener letras del apellido según estado civil
       
       REGLAS DE NEGOCIO:
       - CASADO / AUC / ACUERDO DE UNION CIVIL: dos primeras letras
       - DIVORCIADO / SOLTERO: primera y última letra
       - VIUDO: antepenúltima y penúltima letra
       - SEPARADO: dos últimas letras
       - OTROS: dos primeras letras (por defecto)
       
       RETORNA: 2 caracteres en minúscula
       ================================================================ */
    FUNCTION f_letras_apellido(
        p_estado_civil VARCHAR2,
        p_appaterno    VARCHAR2
    ) RETURN VARCHAR2
    IS
        v_ec  VARCHAR2(50);
        v_ap  VARCHAR2(200);
        v_len PLS_INTEGER;
        v_res VARCHAR2(2);
    BEGIN
        v_ec  := UPPER(TRIM(p_estado_civil));
        v_ap  := TRIM(p_appaterno);
        v_len := LENGTH(v_ap);

        /* Validación: apellido muy corto */
        IF v_len = 0 THEN
            RETURN 'xx';
        ELSIF v_len = 1 THEN
            RETURN LOWER(v_ap || v_ap);
        END IF;

        /* Aplicar reglas según estado civil */
        IF v_ec IN ('CASADO', 'AUC', 'ACUERDO DE UNION CIVIL') THEN
            v_res := SUBSTR(v_ap, 1, 2);  -- Dos primeras letras
            
        ELSIF v_ec IN ('DIVORCIADO', 'SOLTERO') THEN
            v_res := SUBSTR(v_ap, 1, 1) || SUBSTR(v_ap, -1, 1);  -- Primera y última
            
        ELSIF v_ec = 'VIUDO' THEN
            IF v_len >= 3 THEN
                v_res := SUBSTR(v_ap, -3, 1) || SUBSTR(v_ap, -2, 1);  -- Antepenúltima y penúltima
            ELSE
                v_res := SUBSTR(v_ap, 1, 2);
            END IF;
            
        ELSIF v_ec = 'SEPARADO' THEN
            v_res := SUBSTR(v_ap, -2, 2);  -- Dos últimas
            
        ELSE
            v_res := SUBSTR(v_ap, 1, 2);  -- Por defecto
        END IF;

        RETURN LOWER(v_res);
    END f_letras_apellido;

BEGIN
    /* ================================================================
       PASO 1: TOMAR FECHA DE PROCESO DESDE BIND VARIABLE
       
       USO DE BIND VARIABLE:
       - :b_fecha_proceso es la variable de sustitución
       - Permite parametrizar el proceso sin cambiar el código
       - Se usa en todos los cálculos de fecha dentro del bloque
       ================================================================ */
    v_fecha_proceso := TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY');

    /* ================================================================
       PASO 2: TRUNCAR TABLA DESTINO CON SQL DINÁMICO
       
       USO DE SQL DINÁMICO:
       - EXECUTE IMMEDIATE permite ejecutar comandos DDL
       - TRUNCATE es más eficiente que DELETE para limpiar la tabla
       - Permite re-ejecutar el script sin duplicar datos
       ================================================================ */
    EXECUTE IMMEDIATE 'TRUNCATE TABLE usuario_clave';

    /* ================================================================
       PASO 3: CONTAR TOTAL ESPERADO (para control transaccional)
       
       Este conteo se usa al final para validar que se procesaron
       todos los empleados esperados antes de hacer COMMIT
       ================================================================ */
    SELECT COUNT(*)
    INTO   v_total_esperado
    FROM   empleado
    WHERE  id_emp BETWEEN 100 AND 320;

    /* ================================================================
       PASO 4: ITERACIÓN REQUERIDA (100 al 320)
       
       REQUISITO DE PAUTA:
       - Debe iterar desde id_emp 100 hasta 320
       - Se usa FOR loop (la variable v_id_iter se declara implícitamente)
       - Si un id no existe, se omite y continúa (EXCEPTION NO_DATA_FOUND)
       ================================================================ */
    FOR v_id_iter IN 100 .. 320
    LOOP
        BEGIN
            /* ------------------------------------------------------------
               PASO 4.1: TRAER DATOS DEL EMPLEADO (SELECT con JOIN)
               
               Se trae toda la información necesaria en una sola consulta
               para aplicar las reglas de negocio en PL/SQL
               ------------------------------------------------------------ */
            SELECT e.id_emp,
                   e.numrun_emp,
                   e.dvrun_emp,
                   e.pnombre_emp,
                   e.appaterno_emp,
                   e.fecha_nac,
                   e.fecha_contrato,
                   e.sueldo_base,
                   ec.nombre_estado_civil
            INTO   v_id_emp,
                   v_numrun,
                   v_dvrun,
                   v_pnombre,
                   v_appaterno,
                   v_fecha_nac,
                   v_fecha_contrato,
                   v_sueldo_base,
                   v_estado_civil
            FROM   empleado e
                   JOIN estado_civil ec ON ec.id_estado_civil = e.id_estado_civil
            WHERE  e.id_emp = v_id_iter;

            /* ------------------------------------------------------------
               CONSTRUCCIÓN: NOMBRE_EMPLEADO
               Requerido por la tabla destino
               ------------------------------------------------------------ */
            v_nombre_empleado := TRIM(v_pnombre) || ' ' || TRIM(v_appaterno);

            /* ============================================================
               REGLAS DE NEGOCIO: CONSTRUCCIÓN DE NOMBRE_USUARIO (PL/SQL)
               
               FORMATO: LetraEC + 3LetrasNombre + LargoNombre + * + 
                        UltimoDigSueldo + DV + AñosTrabajados [+ X si <10 años]
               
               COMPONENTES:
               1. Primera letra del estado civil (minúscula)
               2. Tres primeras letras del primer nombre (minúscula)
               3. Largo del primer nombre (número)
               4. Asterisco (*)
               5. Último dígito del sueldo base
               6. Dígito verificador del RUN
               7. Años trabajados (calculado con MONTHS_BETWEEN)
               8. X si tiene menos de 10 años trabajando
               ============================================================ */
            
            /* 1. Primera letra del estado civil en minúscula */
            v_letra_ec := LOWER(SUBSTR(TRIM(v_estado_civil), 1, 1));
            
            /* 2. Tres primeras letras del nombre en minúscula */
            v_3letras_nombre := LOWER(SUBSTR(TRIM(v_pnombre), 1, 3));
            
            /* 3. Largo del nombre */
            v_largo_nombre := LENGTH(TRIM(v_pnombre));
            
            /* 4. Último dígito del sueldo */
            v_ultimo_dig_sueldo := SUBSTR(TO_CHAR(v_sueldo_base), -1, 1);
            
            /* 5. Calcular años trabajados usando la BIND VARIABLE
               NOTA: Se usa v_fecha_proceso que viene de :b_fecha_proceso
                     Esto demuestra el uso de la bind variable en cálculos */
            v_anios_trabajados := TRUNC(MONTHS_BETWEEN(v_fecha_proceso, v_fecha_contrato) / 12);

            /* Ensamblar el nombre de usuario */
            v_nombre_usuario :=
                v_letra_ec ||
                v_3letras_nombre ||
                TO_CHAR(v_largo_nombre) ||
                '*' ||
                v_ultimo_dig_sueldo ||
                v_dvrun ||
                TO_CHAR(v_anios_trabajados);

            /* 6. Agregar 'X' si tiene menos de 10 años trabajando */
            IF v_anios_trabajados < 10 THEN
                v_nombre_usuario := v_nombre_usuario || 'X';
            END IF;

            /* ============================================================
               REGLAS DE NEGOCIO: CONSTRUCCIÓN DE CLAVE_USUARIO (PL/SQL)
               
               FORMATO: TercerDigRUN + AñoNac+2 + Ult3DigSueldo-1 + 
                        2LetrasApellido + IdEmp + MMYYYY
               
               COMPONENTES:
               1. Tercer dígito del RUN
               2. Año de nacimiento + 2
               3. Últimos 3 dígitos del sueldo - 1 (formato 3 dígitos)
               4. Dos letras del apellido según estado civil
               5. ID del empleado
               6. Mes y año de proceso (MMYYYY) desde bind variable
               ============================================================ */
            
            /* 1. Tercer dígito del RUN */
            v_tercer_dig_run := SUBSTR(TO_CHAR(v_numrun), 3, 1);
            
            /* 2. Año de nacimiento + 2 */
            v_anio_nac_mas2 := TO_NUMBER(TO_CHAR(v_fecha_nac, 'YYYY')) + 2;
            
            /* 3. Últimos 3 dígitos del sueldo - 1
               IMPORTANTE: Se usa LPAD para mantener formato de 3 dígitos
               Ejemplo: si sueldo termina en 100, resultado es 099 (no 99) */
            v_ult3_sueldo_menos1 :=
                TO_NUMBER(SUBSTR(LPAD(TO_CHAR(v_sueldo_base), 3, '0'), -3, 3)) - 1;
            
            /* 4. Letras del apellido según estado civil (función interna) */
            v_letras_apellido := f_letras_apellido(v_estado_civil, v_appaterno);
            
            /* 5. Mes y año de proceso usando la BIND VARIABLE
               NOTA: Se usa v_fecha_proceso que viene de :b_fecha_proceso
                     Esto demuestra el uso de la bind variable en cálculos */
            v_mmyyyy := TO_CHAR(v_fecha_proceso, 'MMYYYY');

            /* Ensamblar la clave (con LPAD para mantener formato de 3 dígitos) */
            v_clave_usuario :=
                v_tercer_dig_run ||
                TO_CHAR(v_anio_nac_mas2) ||
                LPAD(TO_CHAR(v_ult3_sueldo_menos1), 3, '0') ||  -- Formato 3 dígitos
                v_letras_apellido ||
                TO_CHAR(v_id_emp) ||
                v_mmyyyy;

            /* ------------------------------------------------------------
               INSERT: Guardar el resultado en la tabla destino
               ------------------------------------------------------------ */
            INSERT INTO usuario_clave (
                id_emp,
                numrun_emp,
                dvrun_emp,
                nombre_empleado,
                nombre_usuario,
                clave_usuario
            ) VALUES (
                v_id_emp,
                v_numrun,
                v_dvrun,
                v_nombre_empleado,
                v_nombre_usuario,
                v_clave_usuario
            );

            /* Incrementar contador de procesados */
            v_total_procesado := v_total_procesado + 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                /* Si no existe empleado para ese id, continuar con el siguiente
                   Esto permite iterar del 100 al 320 aunque no todos existan */
                NULL;
        END;
    END LOOP;

    /* ================================================================
       CONTROL TRANSACCIONAL (requisito de pauta)
       
       COMMIT solo si:
       - Se procesaron TODOS los empleados esperados
       - No hubo ningún error en el proceso
       
       ROLLBACK si:
       - Faltaron empleados por procesar
       - Hubo algún error (capturado en EXCEPTION del bloque principal)
       
       Esto garantiza que NO quede data parcial en caso de error
       ================================================================ */
    IF v_total_procesado = v_total_esperado THEN
        COMMIT;  -- Guardar todos los cambios
    ELSE
        ROLLBACK;  -- Deshacer todos los cambios
        RAISE_APPLICATION_ERROR(
            -20040,
            'Proceso incompleto. Esperados: ' || v_total_esperado ||
            ', Procesados: ' || v_total_procesado
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        /* Cualquier error no capturado: hacer ROLLBACK y relanzar */
        ROLLBACK;
        RAISE;
END;
/















/* =====================================================================
   PARTE E - VERIFICACIONES Y VALIDACIONES
   
   PROPÓSITO:
   - Validar que el proceso se ejecutó correctamente
   - Verificar que los datos cumplen con las reglas de negocio
   - Evidenciar el correcto funcionamiento del script
   ===================================================================== */

/* =====================================================================
   VERIFICACIÓN 0: MOSTRAR PARÁMETROS USADOS
   
   EVIDENCIA:
   - Muestra el valor de la BIND VARIABLE usada
   - Muestra el MMYYYY esperado en las claves
   ===================================================================== */
SELECT :b_fecha_proceso AS fecha_proceso_param,
       TO_CHAR(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), 'MMYYYY') AS mmyyyy_esperado
FROM   dual;


/* =====================================================================
   VERIFICACIÓN 1: CANTIDAD DE REGISTROS
   
   CRITERIO DE ÉXITO:
   - Filas esperadas debe ser igual a filas cargadas
   - Esto valida que se procesaron TODOS los empleados
   ===================================================================== */
SELECT (SELECT COUNT(*) 
        FROM   empleado 
        WHERE  id_emp BETWEEN 100 AND 320) AS filas_esperadas,
       (SELECT COUNT(*) 
        FROM   usuario_clave)              AS filas_cargadas
FROM   dual;
-- RESULTADO ESPERADO: Los dos números deben ser iguales

/* Ver solo el total cargado */
SELECT COUNT(*) AS filas_usuario_clave
FROM   usuario_clave;


/* =====================================================================
   VERIFICACIÓN 2: DATOS ORDENADOS POR IDENTIFICACIÓN
   
   - Los datos deben mostrarse ordenados por identificación (id_emp)
   - La tabla no garantiza orden físico, por eso usamos ORDER BY
   ===================================================================== */
SELECT id_emp,
       numrun_emp,
       dvrun_emp,
       nombre_empleado,
       nombre_usuario,
       clave_usuario
FROM   usuario_clave
ORDER BY id_emp;


/* =====================================================================
   VERIFICACIÓN 3: FORMATO BÁSICO
   
   VALIDACIONES:
   - NOMBRE_USUARIO debe contener '*'
   - CLAVE_USUARIO debe terminar con MMYYYY de la fecha de proceso
   
   RESULTADO ESPERADO: 0 filas (ningún error de formato)
   ===================================================================== */
SELECT id_emp,
       nombre_usuario,
       clave_usuario
FROM   usuario_clave
WHERE  nombre_usuario NOT LIKE '%*%'
   OR  SUBSTR(clave_usuario, -6) <> TO_CHAR(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), 'MMYYYY');
-- RESULTADO ESPERADO: 0 filas


/* =====================================================================
   VERIFICACIÓN 3.1: ASTERISCO ÚNICO
   
   VALIDACIÓN:
   - NOMBRE_USUARIO debe contener exactamente 1 asterisco
   - Ni más ni menos
   
   RESULTADO ESPERADO: 0 filas (todos tienen exactamente 1 asterisco)
   ===================================================================== */
SELECT id_emp,
       nombre_usuario,
       (LENGTH(nombre_usuario) - LENGTH(REPLACE(nombre_usuario, '*', ''))) AS cantidad_asteriscos
FROM   usuario_clave
WHERE  (LENGTH(nombre_usuario) - LENGTH(REPLACE(nombre_usuario, '*', ''))) <> 1;
-- RESULTADO ESPERADO: 0 filas


/* =====================================================================
   VERIFICACIÓN 3.2: SUFIJO MMYYYY
   
   VALIDACIÓN:
   - CLAVE_USUARIO debe terminar exactamente con MMYYYY
   - El MMYYYY debe corresponder a la fecha de proceso
   
   RESULTADO ESPERADO: 0 filas (todos tienen sufijo correcto)
   ===================================================================== */
SELECT id_emp,
       clave_usuario,
       SUBSTR(clave_usuario, -6) AS mmyyyy_en_clave,
       TO_CHAR(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), 'MMYYYY') AS mmyyyy_esperado
FROM   usuario_clave
WHERE  SUBSTR(clave_usuario, -6) <> TO_CHAR(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), 'MMYYYY');
-- RESULTADO ESPERADO: 0 filas


/* =====================================================================
   VERIFICACIÓN 4: REGLA DE LA 'X' (AÑOS TRABAJADOS)
   
   REGLA DE NEGOCIO:
   - Si años_trabajados < 10  => NOMBRE_USUARIO debe terminar en 'X'
   - Si años_trabajados >= 10 => NOMBRE_USUARIO NO debe terminar en 'X'
   
   RESULTADO ESPERADO: 0 filas (todos cumplen la regla)
   ===================================================================== */
SELECT uc.id_emp,
       uc.nombre_usuario,
       TRUNC(MONTHS_BETWEEN(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), e.fecha_contrato) / 12) AS anios_trabajados,
       CASE 
           WHEN TRUNC(MONTHS_BETWEEN(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), e.fecha_contrato) / 12) < 10 
           THEN 'Debe terminar en X'
           ELSE 'NO debe terminar en X'
       END AS regla_esperada,
       CASE 
           WHEN uc.nombre_usuario LIKE '%X' 
           THEN 'Termina en X'
           ELSE 'NO termina en X'
       END AS estado_actual
FROM   usuario_clave uc
       JOIN empleado e ON e.id_emp = uc.id_emp
WHERE  (TRUNC(MONTHS_BETWEEN(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), e.fecha_contrato) / 12) < 10
        AND uc.nombre_usuario NOT LIKE '%X')
   OR  (TRUNC(MONTHS_BETWEEN(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), e.fecha_contrato) / 12) >= 10
        AND uc.nombre_usuario LIKE '%X');
-- RESULTADO ESPERADO: 0 filas


/* ==========================================================
   
   NOTA SOBRE EL PARCHE AL SCRIPT DEL PROFESOR:
   - Se agregaron 2 líneas para manejar formatos de fecha
   - Línea 1: ALTER SESSION SET NLS_DATE_FORMAT = 'DDMMYYYY';
              (antes de INSERT INTO empleado)
   - Línea 2: ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';
              (después de INSERT INTO empleado)
   - Esto corrige la mezcla de formatos en los datos originales
   ===================================================================== */
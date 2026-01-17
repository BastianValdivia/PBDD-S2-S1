/* =====================================================================
   SCRIPT PARA BORRAR TODO Y EMPEZAR DE NUEVO
   
   ¿PARA QUÉ SIRVE?
   Este script borra completamente el usuario y todo lo que creamos
   para poder empezar desde cero si algo sale mal.
   
   ¿QUIÉN LO EJECUTA?
   - Usuario: SYSTEM (el administrador)
   - Base de datos: XEPDB1
   
   ¿CÓMO USARLO?
   - Abre SQL Developer
   - Conéctate como SYSTEM
   - Ejecuta todo con F5 (Run Script)
   ===================================================================== */

SET SERVEROUTPUT ON;


/* ==========================================================
   PASO 1 - VERIFICAR QUE ESTAMOS EN EL LUGAR CORRECTO
   ========================================================== */

/* Ver en qué base de datos estamos */
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS con_name
FROM   dual;

/* Detener si no estamos en XEPDB1 */
DECLARE
    v_con_name VARCHAR2(30);
BEGIN
    v_con_name := SYS_CONTEXT('USERENV', 'CON_NAME');
    
    IF UPPER(v_con_name) <> 'XEPDB1' THEN
        RAISE_APPLICATION_ERROR(
            -20999,
            'ERROR: Estás en ' || v_con_name ||
            '. Debes conectarte a XEPDB1 primero.'
        );
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('✓ Perfecto, estamos en XEPDB1');
END;
/


/* ==========================================================
   PASO 2 - BORRAR SINÓNIMOS PÚBLICOS (SI EXISTEN)
   ========================================================== */

/* Los sinónimos son como "atajos" a las tablas.
   Puede que no existan, pero los borramos por si acaso */
DECLARE
    CURSOR c_syn IS
        SELECT synonym_name
        FROM   dba_synonyms
        WHERE  owner = 'PUBLIC'
          AND  synonym_name IN (
                   'EMPLEADO',
                   'USUARIO_CLAVE',
                   'ESTADO_CIVIL'
               );
    
    v_count PLS_INTEGER := 0;
BEGIN
    FOR r IN c_syn LOOP
        EXECUTE IMMEDIATE 'DROP PUBLIC SYNONYM ' || r.synonym_name;
        DBMS_OUTPUT.PUT_LINE('✓ Borrado sinónimo: ' || r.synonym_name);
        v_count := v_count + 1;
    END LOOP;
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✓ No había sinónimos para borrar');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ Total de sinónimos borrados: ' || v_count);
    END IF;
END;
/


/* ==========================================================
   PASO 3 - BORRAR EL USUARIO Y TODO LO QUE CREÓ
   ========================================================== */

/* Esto borra:
   - El usuario SUMATIVA_2206_P1
   - Todas sus tablas
   - Todas sus secuencias
   - Todos sus procedimientos
   - Todo lo que haya creado */
BEGIN
    EXECUTE IMMEDIATE 'DROP USER SUMATIVA_2206_P1 CASCADE';
    DBMS_OUTPUT.PUT_LINE('✓ Usuario borrado completamente');
    DBMS_OUTPUT.PUT_LINE('  - Usuario eliminado');
    DBMS_OUTPUT.PUT_LINE('  - Todas las tablas eliminadas');
    DBMS_OUTPUT.PUT_LINE('  - Todos los objetos eliminados');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1918 THEN
            DBMS_OUTPUT.PUT_LINE('✓ El usuario no existía (está bien)');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ Error al borrar usuario:');
            RAISE;
        END IF;
END;
/


/* ==========================================================
   PASO 4 - BORRAR ROLES (SI EXISTEN)
   ========================================================== */

/* Los roles son grupos de permisos.
   Puede que el profesor haya creado algunos, los borramos por si acaso */
DECLARE
    TYPE t_roles IS TABLE OF VARCHAR2(128);
    v_roles t_roles := t_roles(
        'ROL_SUMATIVA_2206',
        'ROLE_SUMATIVA_2206',
        'SUMATIVA_2206_ROLE'
    );
    
    v_cnt   NUMBER;
    v_total PLS_INTEGER := 0;
BEGIN
    FOR i IN 1 .. v_roles.COUNT LOOP
        SELECT COUNT(*)
        INTO   v_cnt
        FROM   dba_roles
        WHERE  role = v_roles(i);
        
        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP ROLE ' || v_roles(i);
            DBMS_OUTPUT.PUT_LINE('✓ Borrado rol: ' || v_roles(i));
            v_total := v_total + 1;
        END IF;
    END LOOP;
    
    IF v_total = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✓ No había roles para borrar');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ Total de roles borrados: ' || v_total);
    END IF;
END;
/


/* ==========================================================
   PASO 5 - VERIFICAR QUE TODO SE BORRÓ CORRECTAMENTE
   ========================================================== */

/* Verificar que el usuario ya no existe */
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO   v_count
    FROM   dba_users
    WHERE  username = 'SUMATIVA_2206_P1';
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('==========================================================');
        DBMS_OUTPUT.PUT_LINE('✓ ¡TODO BORRADO EXITOSAMENTE!');
        DBMS_OUTPUT.PUT_LINE('==========================================================');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Resumen de lo que se borró:');
        DBMS_OUTPUT.PUT_LINE('  ✓ Usuario SUMATIVA_2206_P1: YA NO EXISTE');
        DBMS_OUTPUT.PUT_LINE('  ✓ Tablas: TODAS BORRADAS');
        DBMS_OUTPUT.PUT_LINE('  ✓ Datos: TODOS BORRADOS');
        DBMS_OUTPUT.PUT_LINE('  ✓ Objetos: TODOS BORRADOS');
        DBMS_OUTPUT.PUT_LINE('  ✓ Roles: BORRADOS (si existían)');
        DBMS_OUTPUT.PUT_LINE('  ✓ Sinónimos: BORRADOS (si existían)');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('==========================================================');
        DBMS_OUTPUT.PUT_LINE('¿QUÉ HACER AHORA?');
        DBMS_OUTPUT.PUT_LINE('==========================================================');
        DBMS_OUTPUT.PUT_LINE('Ahora puedes empezar de nuevo:');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('1. Ejecutar el script principal (Parte A)');
        DBMS_OUTPUT.PUT_LINE('   - Esto creará el usuario otra vez');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('2. Ejecutar el script del profesor');
        DBMS_OUTPUT.PUT_LINE('   - Esto creará las tablas');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('3. Continuar con las Partes B, C, D y E');
        DBMS_OUTPUT.PUT_LINE('   - Ejecutar el programa principal');
        DBMS_OUTPUT.PUT_LINE('==========================================================');
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✗ ATENCIÓN: El usuario todavía existe');
        DBMS_OUTPUT.PUT_LINE('  Revisa los mensajes de error anteriores');
    END IF;
END;
/


/* ==========================================================
   FIN DEL SCRIPT DE RESET
   
   ¿QUÉ HIZO ESTE SCRIPT?
   - Verificó que estás en XEPDB1
   - Borró todos los sinónimos relacionados
   - Borró el usuario y todo lo que tenía
   - Borró los roles relacionados
   - Verificó que todo se borró correctamente
   
   Ahora estás listo para empezar de nuevo desde cero
   ========================================================== */
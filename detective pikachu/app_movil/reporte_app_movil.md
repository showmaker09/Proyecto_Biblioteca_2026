# Reporte de testing — App móvil

## Puntos reportados

### 1. Quitar el indicador de depuración
- Eliminar de la aplicación el indicador o marca de *debug* visible en pantalla.
- La interfaz de uso normal no debe mostrar elementos propios de depuración.

### 2. Carga automática de libros en la biblioteca
- Quitar el botón **Cargar más** de la opción Biblioteca.
- Cargar los libros automáticamente al llegar al final de los resultados ya mostrados, mientras el usuario baja por la lista.
- Usar carga progresiva: no mostrar todos los libros de golpe para evitar ralentizar la aplicación.
- Mantener visibles los libros existentes mientras se cargan los siguientes.

### 3. Separar los controles de lectura
- Separar visualmente los botones y controles disponibles durante la lectura para que cada acción se distinga con facilidad.
- Organizar los controles con suficiente espacio y una presentación clara de lo que hace cada uno.

### 4. Ajustar la función de la barra superior de lectura
- Cambiar la función de la barra y sus controles ubicados en la parte superior de la página.
- La barra debe permitir desplazarse dentro de la página actual, no cambiar de página.

### 5. Agregar un icono para la aplicación
- Crear un icono sencillo que identifique la aplicación y represente una biblioteca.

### 6. Completar botones y funciones de filtros
- Completar la selección de idioma: el español debe estar disponible de forma completa y debe agregarse inglés, además de permitir incorporar otros idiomas.
- Agregar la selección de género y sus botones u opciones para filtrar los libros por género.

### 7. Unificar el tamaño de los libros
- Ajustar la presentación para que las tarjetas o portadas de los libros tengan el mismo tamaño.

### 8. Evitar que los controles del sistema obstruyan la aplicación
- Ajustar la vista para que los botones principales de la aplicación no se superpongan ni choquen con los botones de navegación del dispositivo.
- Considerar los controles del sistema en las distintas pantallas y apartados, no solo en la vista principal.

### 9. Agregar géneros en el inicio
- Incorporar en la pantalla de inicio una forma visible de explorar y organizar los libros por género, por ejemplo, mediante botones o filtros de género.
- Si un libro no tiene un género asignado, clasificarlo como **Sin especificar** en lugar de asignarlo a un género no confirmado.

### 10. Agregar un botón para cancelar o limpiar filtros
- Incluir un botón **X** o **Cancelar** que permita limpiar el texto del filtro de una sola vez, sin borrarlo letra por letra.
- Actualizar los resultados conforme cambia el contenido del filtro.
- Cuando el campo de búsqueda esté vacío, mostrar los libros predeterminados en lugar de dejar la lista vacía.

### 11. Vincular la carga de libros con el usuario autenticado
- Asociar cada libro que se suba o escanee con el usuario de la cuenta que inició sesión.
- No pedir al administrador que seleccione manualmente quién puede subirlo; la cuenta autenticada debe determinar el usuario responsable.
- Cada libro debe quedar vinculado a un solo usuario para identificar quién lo escaneó o subió.

### 12. Indicar los campos faltantes al publicar
- En la opción para publicar un libro, remarcar las casillas obligatorias que falten completar.
- Indicar junto a cada casilla qué información se necesita para corregir la validación y completar la publicación.

### 13. Quitar el botón «Cargar más asignaciones» del progreso logístico
- En **Ajustes > Progreso logístico**, quitar el botón **Cargar más asignaciones** de la parte inferior.
- Cargar las siguientes asignaciones automáticamente al llegar al límite de las que ya se muestran.

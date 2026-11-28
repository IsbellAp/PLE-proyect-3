# Objectilang: Proyecto 4

Aplicación de escritorio en Kotlin que ejecuta programas de Objectilang (`.ol`). La aplicación llama a Rascal (`RunnerJson.rsc`), que parsea el archivo, revisa los tipos, genera y ejecuta el Java, y devuelve el resultado en JSON para mostrarlo en la ventana.

Autores: Edy Lane Martínez Rojas, Isabella Casallas Abril. El documento del proyecto es `Proyecto4.pdf`.

## 1. Requisitos

- **Java JDK 17 o 21.** Gradle 8.5 no funciona con Java 22 o superior. Revisar con `java -version`.
- Gradle **no** hace falta: la carpeta `kotlin-app` trae `gradlew`, que descarga Gradle 8.5 la primera vez.

## 2. Descargar los jars de Rascal y TypePal

No están en el repositorio. Se descargan **dentro de la carpeta `objectilang`** (al lado de `pom.xml`).

Windows (PowerShell):

```powershell
cd objectilang
Invoke-WebRequest "https://releases.usethesource.io/maven/org/rascalmpl/rascal/0.43.0/rascal-0.43.0.jar" -OutFile "rascal-shell-stable.jar"
Invoke-WebRequest "https://releases.usethesource.io/maven/org/rascalmpl/typepal/0.17.0/typepal-0.17.0.jar" -OutFile "typepal-0.17.0.jar"
```

Linux / Mac:

```bash
cd objectilang
curl -L -o rascal-shell-stable.jar "https://releases.usethesource.io/maven/org/rascalmpl/rascal/0.43.0/rascal-0.43.0.jar"
curl -L -o typepal-0.17.0.jar "https://releases.usethesource.io/maven/org/rascalmpl/typepal/0.17.0/typepal-0.17.0.jar"
```

## 3. Probar Rascal (opcional)

Siempre desde la carpeta `objectilang`. Desde otra carpeta Rascal no encuentra los módulos.

```bash
java -jar rascal-shell-stable.jar RunnerJson instance/enunciado1.ol
```

Primero salen unas líneas `[INFO]` y al final una línea JSON que empieza con `{"success":true`. La primera vez tarda más porque Rascal construye el parser.

## 4. Ejecutar la aplicación

Desde la carpeta `objectilang/kotlin-app`:

- Windows: `.\gradlew.bat run`
- Linux / Mac: `./gradlew run`

La primera vez descarga Gradle y las librerías (unos minutos). Luego se abre la ventana **Objectilang — Runner**.

1. Escribir la ruta completa de un archivo `.ol` o elegirlo con **Buscar** (los ejemplos están en `objectilang/instance`).
2. Pulsar **Correr**. El botón se activa cuando hay una ruta escrita.
3. La ventana muestra el estado del parser, de los tipos y de la semántica (OK o FAIL), los objetos y métodos del archivo, los errores, el Java generado y la salida del programa.

## 5. Archivos para probar

| Archivo | Resultado esperado |
|---|---|
| `enunciado1.ol` | Todo en OK, objetos Animal, Dog, Cat y List, y la salida del programa |
| `ejec03_metodos.ol` | Todo en OK, con el método Cat.talk en la lista |
| `falla_ifSinThen.ol` | Parse en FAIL con el error de Rascal (línea y columna) |
| `t_tipo_malo.ol` | Types en FAIL con el error de tipos |
| `t_malo.ol` | Semántica en FAIL: `Undefined object NoExiste` |
| `errorEjec_sinCuerpo.ol` | Error de ejecución: el método `transform` no tiene cuerpo |

## 6. Problemas comunes

| Mensaje | Solución |
|---|---|
| `Could not import module RunnerJson` | Ejecutar Rascal desde la carpeta `objectilang` |
| `No se encontró rascal-shell-stable.jar` | Falta el jar o tiene otro nombre: repetir el paso 2 |
| Gradle dice que la versión de Java no es compatible | Instalar un JDK 21. Si hay varios, crear `kotlin-app/gradle.properties` con la línea `org.gradle.java.home=<ruta del JDK 21>` |
| Error de Rascal sobre `analysis::typepal` | Con Maven instalado, ejecutar una vez `mvn dependency:resolve` dentro de `objectilang` |
| `./gradlew: permiso denegado` (Linux / Mac) | `chmod +x gradlew` |

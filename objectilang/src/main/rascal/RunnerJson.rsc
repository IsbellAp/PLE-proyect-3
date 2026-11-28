module RunnerJson

// Se corre desde la carpeta objectilang/ (ahí están META-INF/RASCAL.MF y pom.xml):
// java -jar rascal-shell-stable.jar RunnerJson instance/enunciado1.ol
// No se importa AST: su Programa choca con el Programa de Syntax. Los valores del AST se manejan como value y se recorren con patrones por nombre ("objeto"(...)).
import Syntax;
import Parser;      // parsePrograma
import Implode;     // implodePrograma (construye el AST)
import Check;       // modeloDeArbol (chequeo de tipos con TypePal)
import Generador;   // generar, nombreClase, correrJava (genera el Java y lo ejecuta)
import ParseTree;
import Message;
import IO;
import Set;
import List;
import String;
import lang::json::IO;  // writeJSON (AST a un archivo JSON)


// utilidades para construir el JSON manualmente


// escapa caracteres especiales dentro de strings JSON
str esc(str s) =
    replaceAll(replaceAll(replaceAll(replaceAll(replaceAll(
        s, "\\", "\\\\"), "\"", "\\\""), "\n", "\\n"), "\r", "\\r"), "\t", "\\t");

// convierte una lista de strings a un arreglo JSON  ["a","b","c"]
str jsonArr(list[str] items) =
    "[<intercalate(", ", [ "\"<esc(i)>\"" | i <- items ])>]";

// Construye el objeto JSON de resultado final.
// IMPORTANTE: los nombres de las claves DEBEN coincidir con los campos de RunResult.kt
// objetos y metodos son la lista de "módulos" del archivo (keyword params: si no se pasan, quedan [])
str jsonResult(
    bool success,
    str modName,
    bool parseOk,
    bool tcOk,        // type check ok
    bool semOk,       // semántica ok
    list[str] tcErrs,
    list[str] semErrs,
    list[str] output,
    str err,
    str codigoFormateado,
    str resumen,            // resumen del AST
    list[str] objetos = [],
    list[str] metodos = []
) =
    "{\"success\":<success>,"
    + "\"module\":\"<esc(modName)>\","
    + "\"parseOk\":<parseOk>,"
    + "\"typeCheckOk\":<tcOk>,"
    + "\"semanticOk\":<semOk>,"
    + "\"typeErrors\":<jsonArr(tcErrs)>,"
    + "\"semanticErrors\":<jsonArr(semErrs)>,"
    + "\"output\":<jsonArr(output)>,"
    + "\"error\":\"<esc(err)>\","
    + "\"codigoFormateado\":\"<esc(codigoFormateado)>\","
    + "\"resumen\":\"<esc(resumen)>\","
    + "\"objetos\":<jsonArr(objetos)>,"
    + "\"metodos\":<jsonArr(metodos)>}";

// Los mensajes de Check sobre la regla de existencia van como errores semánticos; el resto son errores de tipos.
bool esDeExistencia(str msg) =
    any(k <- ["Undefined", "Double", "no existe", "ya está definido", "repetido", "hered", "Herencia", "no tiene un"],
        contains(msg, k));

// Punto de entrada, Kotlin llama a este módulo con la ruta del archivo fuente

void main(list[str] args) {

    //Leer el archivo fuente
    // file y modName van fuera del try: se usan en el resto de main
    loc file;
    if (isEmpty(args)) {
        // archivo por defecto para pruebas rápidas desde Rascal directamente
        file = |cwd:///instance/enunciado1.ol|;
    } else {
        str arg0 = replaceAll(args[0], "\\", "/");       // normaliza separadores de Windows (\ -> /)
        if (startsWith(arg0, "/"))
            file = |file:///|[path = arg0];
        else if (size(arg0) >= 2 && arg0[1] == ":")      // ruta absoluta de Windows: C:/...
            file = |file:///|[path = "/" + arg0];
        else
            file = |cwd:///| + arg0;                      // ruta relativa (ej. instance/enunciado1.ol)
    }
    str modName = file[extension = ""].file;
    str src;
    try {
        src = readFile(file);
    } catch e: {
        println(jsonResult(false, modName, false, false, false, [], [], [], "No se pudo leer el archivo: <e>", "", ""));
        return;
    }

    //Parsing
    start[Programa] cst;
    try {
        cst = parsePrograma(src, file);
    } catch ParseError(loc at): {
        println(jsonResult(false, modName, false, false, false, [], [], [], "Error de parsing en <at>", "", ""));
        return;
    } catch e: {
        println(jsonResult(false, modName, false, false, false, [], [], [], "Error de parsing: <e>", "", ""));
        return;
    }

    // Construcción del AST
    value ast;
    try {
        ast = implodePrograma(cst.top);
    } catch e: {
        println(jsonResult(false, modName, true, false, false, [], [], [], "Error construyendo AST: <e>", "", ""));
        return;
    }

    // AST a JSON: instance/output/<archivo>.ast.json
    loc carpetaSalida = file.parent + "output";
    if (!exists(carpetaSalida)) mkDirectory(carpetaSalida);
    try {
        writeJSON(carpetaSalida + "<modName>.ast.json", ast);
    } catch _: ;

    // Lista de módulos del archivo: los objetos y sus métodos
    list[str] objetos = [ n | /"objeto"(str n, _, _, _) := ast ];
    list[str] metodos = [ "<ob>.<m>" | /"metodo"(str ob, str m, _, _, _) := ast ];
    str resumen = "<size(objetos)> objeto(s), <size(metodos)> método(s)";

    //Pretty Printer
    str codigoFormateado = "";

    //Verificación semántica
    list[str] tcErrs = [];
    list[str] semErrs = [];
    bool semOk = true;
    try {
        tm = modeloDeArbol(cst);
        for (Message m <- getMessages(tm), m is error) {
            str txt = "línea <m.at.begin.line>: <m.msg>";
            if (esDeExistencia(m.msg)) semErrs += [txt]; else tcErrs += [txt];
        }
    } catch e: {
        println(jsonResult(false, modName, true, false, false, [], [], [], "Error en el chequeo de tipos: <e>", "", resumen, objetos = objetos, metodos = metodos));
        return;
    }
    bool tcOk = isEmpty(tcErrs);
    semOk = isEmpty(semErrs);
    if (!tcOk || !semOk) {
        // con errores no se genera ni se ejecuta el Java
        println(jsonResult(false, modName, true, tcOk, semOk, tcErrs, semErrs, [], "", codigoFormateado, resumen, objetos = objetos, metodos = metodos));
        return;
    }

    // ejecución
    // La función debe devolver list[str] con las líneas de salida
    list[str] output = [];
    try {
        str clase = nombreClase(file);
        loc archivoJava = carpetaSalida + "<clase>.java";
        codigoFormateado = generar(ast, clase, file.file);
        writeFile(archivoJava, codigoFormateado);
        output = [ replaceAll(l, "\r", "") | l <- split("\n", correrJava(archivoJava)) ];
    } catch str errMsg: {
        println(jsonResult(false, modName, true, true, true, [], [], [], "Error en ejecución: <errMsg>", codigoFormateado, resumen, objetos = objetos, metodos = metodos));
        return;
    } catch e: {
        println(jsonResult(false, modName, true, true, true, [], [], [], "Error en ejecución: <e>", codigoFormateado, resumen, objetos = objetos, metodos = metodos));
        return;
    }

    // errores del programa generado: "Error de ejecucion: ..." (OL.reportar) o "Error de compilacion ..." (correrJava)
    str errEjec = intercalate("\n", [ l | l <- output, startsWith(l, "Error de ") ]);

    //Todo OK
    println(jsonResult(errEjec == "", modName, true, true, true, [], [], output, errEjec, codigoFormateado, resumen, objetos = objetos, metodos = metodos));
}
package funkin.menus.credits;

/**
 * Estructura raíz del JSON de créditos.
 * Compatible con el formato de v-slice (entries con header + body).
 *
 * Formato JSON de ejemplo (assets/data/credits.json):
 * {
 *   "entries": [
 *     {
 *       "header": "Directores",
 *       "body": [
 *         { "line": "ninjamuffin99 — Programación" },
 *         { "line": "PhantomArcade — Animación" }
 *       ]
 *     }
 *   ]
 * }
 *
 * Para mods, colocar en: mods/<mod>/data/credits.json
 * Las entradas del mod se añaden AL FINAL de las entradas base.
 */
typedef CreditsData =
{
	var entries:Array<CreditsEntry>;
}

/**
 * Una sección de los créditos (rol, categoría, etc.).
 */
typedef CreditsEntry =
{
	/**
	 * Título de la sección en negrita (p.ej. "Directores", "Arte").
	 * Opcional: si es null, no se muestra cabecera.
	 */
	@:optional
	var header:Null<String>;

	/**
	 * Líneas de texto bajo el header.
	 */
	@:optional
	var body:Array<CreditsLine>;

	/**
	 * Color del header en formato hex sin # (p.ej. "FFFFFF").
	 * Por defecto blanco.
	 */
	@:optional
	var headerColor:Null<String>;

	/**
	 * Color del body en formato hex sin # (p.ej. "CCCCCC").
	 * Por defecto gris claro.
	 */
	@:optional
	var bodyColor:Null<String>;
}

/**
 * Una línea de texto en el body de una entrada.
 */
typedef CreditsLine =
{
	var line:String;
}

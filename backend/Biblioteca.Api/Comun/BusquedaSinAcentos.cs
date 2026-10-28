using System.Globalization;
using System.Text;

namespace Biblioteca.Api.Comun;

/// <summary>
/// "alvaro" -> "[aáàâäãAÁÀÂÄÃ]lv[aá…]r[oó…]": una expresión regular que encuentra el texto con o sin acentos.
/// Se usa con la opción "i" de Mongo para no distinguir mayúsculas. La usan el catálogo y la lista de usuarios.
/// </summary>
public static class BusquedaSinAcentos
{
    static readonly Dictionary<char, string> Variantes = new()
    {
        ['a'] = "aáàâäã",
        ['e'] = "eéèêë",
        ['i'] = "iíìîï",
        ['o'] = "oóòôöõ",
        ['u'] = "uúùûü",
        ['n'] = "nñ",
        ['c'] = "cç",
    };

    const string Especiales = @".*+?^${}()|[]\";

    public static string Patron(string texto)
    {
        var patron = new StringBuilder();
        foreach (var letra in QuitarAcentos(texto).ToLowerInvariant())
        {
            if (Variantes.TryGetValue(letra, out var variantes))
            {
                patron.Append('[').Append(variantes).Append(variantes.ToUpperInvariant()).Append(']');
                continue;
            }
            if (Especiales.Contains(letra)) patron.Append('\\');
            patron.Append(letra);
        }
        return patron.ToString();
    }

    static string QuitarAcentos(string texto)
    {
        var sinAcentos = new StringBuilder(texto.Length);
        foreach (var letra in texto.Normalize(NormalizationForm.FormD))
        {
            if (CharUnicodeInfo.GetUnicodeCategory(letra) != UnicodeCategory.NonSpacingMark) sinAcentos.Append(letra);
        }
        return sinAcentos.ToString();
    }
}

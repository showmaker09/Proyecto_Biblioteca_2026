using System.Text.RegularExpressions;
using Biblioteca.Api.Features.Libros;

namespace Biblioteca.Api.Tests;

public class BusquedaSinAcentosTests
{
    [Theory]
    [InlineData("alvaro", "Don Álvaro o la fuerza del sino")]
    [InlineData("ÁLVARO", "Don Alvaro")]
    [InlineData("ninas", "El sí de las niñas")]
    [InlineData("niñas", "EL SI DE LAS NINAS")]
    [InlineData("vega, lope", "Vega, Lope de")]
    public void Encuentra_el_texto_con_o_sin_acentos(string busqueda, string texto) =>
        Assert.Matches(new Regex(BusquedaSinAcentos.Patron(busqueda), RegexOptions.IgnoreCase), texto);

    [Fact]
    public void Los_caracteres_especiales_se_buscan_literalmente()
    {
        var patron = new Regex(BusquedaSinAcentos.Patron("a.b(c"), RegexOptions.IgnoreCase);
        Assert.Matches(patron, "xa.b(cx");
        Assert.DoesNotMatch(patron, "axbc");
    }
}

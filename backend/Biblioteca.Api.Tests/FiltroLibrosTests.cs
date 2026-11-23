using System.Text.RegularExpressions;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Features.Libros;

namespace Biblioteca.Api.Tests;

public class FiltroLibrosTests
{
    [Theory]
    [InlineData("amor", "el amor humano", true)]
    [InlineData("amor", "amoroso", false)]
    [InlineData("amor", "clamor", false)]
    [InlineData("si", "El sí de las niñas", true)]
    [InlineData("si", "sino", false)]
    [InlineData("a.b", "ver a.b aquí", true)]
    [InlineData("a.b", "xa.bx", false)]
    public void La_palabra_exacta_no_entra_dentro_de_otra(string busqueda, string texto, bool esperado)
    {
        var patron = new Regex(BusquedaSinAcentos.PalabraExacta(busqueda), RegexOptions.IgnoreCase);
        Assert.Equal(esperado, patron.IsMatch(texto));
    }

    [Fact]
    public void Sin_en_contenido_la_busca_sigue_en_titulo_y_autor()
    {
        var filtro = ListarLibros.Filtro(null, "fuente", "es", null, false);
        var json = filtro.ToString();
        Assert.Equal("es", filtro["idioma"].AsString);
        Assert.Contains("titulo", json);
        Assert.Contains("autor", json);
        Assert.DoesNotContain("paginas.texto_completo", json);
    }

    [Fact]
    public void En_contenido_combina_tipo_y_palabra_exacta_en_capitulos_y_paginas()
    {
        var filtro = ListarLibros.Filtro(null, "amor", "es", [" Teatro ", "Teatro", ""], true);
        Assert.Equal("es", filtro["idioma"].AsString);
        var tipos = filtro["temas"].AsBsonDocument["$in"].AsBsonArray;
        Assert.Equal("Teatro", Assert.Single(tipos).AsString);
        var partes = filtro["$or"].AsBsonArray;
        var campos = partes.Select(parte => parte.AsBsonDocument.GetElement(0).Name).ToList();
        Assert.Equal(["capitulos.titulo", "paginas.texto_completo"], campos);
        Assert.Contains("(?<!", partes[0].AsBsonDocument["capitulos.titulo"].AsBsonRegularExpression.Pattern);
    }

    [Fact]
    public void Pedir_por_id_ignora_el_resto_de_filtros()
    {
        var filtro = ListarLibros.Filtro(["001_fuente_ovejuna"], "amor", "es", ["Teatro"], true);
        Assert.True(filtro.Contains("_id"));
        Assert.False(filtro.Contains("idioma"));
        Assert.False(filtro.Contains("$or"));
    }

    [Fact]
    public void El_rango_de_paginas_se_ordena_si_viene_invertido()
    {
        var rango = ListarLibros.RangoPaginas(150, 40);
        Assert.NotNull(rango);
        Assert.Equal(40, rango["total_paginas"]["$gte"].AsInt32);
        Assert.Equal(150, rango["total_paginas"]["$lte"].AsInt32);
        Assert.Null(ListarLibros.RangoPaginas(null, null));
        Assert.Null(ListarLibros.Paginas("no-es-numero"));
        Assert.Null(ListarLibros.Paginas("10001"));
        Assert.Equal(49, ListarLibros.Paginas("49"));
    }

    [Fact]
    public void Filtro_por_genero_agrega_condicion_sin_romper_otros_filtros()
    {
        var filtro = ListarLibros.Filtro(null, "quijote", "es", null, false, "teatro");
        var json = filtro.ToString();
        Assert.Contains("drama|comedy", json);
        Assert.Contains("titulo", json);
        Assert.Equal("es", filtro["$and"].AsBsonArray[0].AsBsonDocument["idioma"].AsString);
    }

    [Fact]
    public void Filtro_por_genero_sin_especificar_usa_nor_y_ignora_desconocidos()
    {
        var sinEspecificar = ListarLibros.Filtro(null, null, null, null, false, "sin_especificar");
        Assert.Contains("$nor", sinEspecificar.ToString());

        var desconocido = ListarLibros.Filtro(null, null, null, null, false, "inexistente");
        Assert.Empty(desconocido);
    }

    [Fact]
    public void Generos_disponibles_filtra_solo_los_presentes_y_agrega_sin_especificar()
    {
        var disponibles = GenerosCatalogo.Disponibles(["Spanish drama", "Spanish poetry"], haySinEspecificar: true);
        Assert.Equal(["teatro", "poesia", "sin_especificar"], disponibles.Select(g => g.Id).ToArray());
        Assert.Equal("Sin especificar", disponibles.Last().Nombre);
    }
}

using System.Text.Json;
using Microsoft.Extensions.Options;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Conventions;
using MongoDB.Driver;

namespace Biblioteca.Api.Comun.Datos;

/// <summary>Las colecciones de la base Biblioteca_Ingenieria en Atlas.</summary>
public sealed class BaseDatos(IMongoClient cliente, IOptions<OpcionesMongo> opciones)
{
    readonly IMongoDatabase bd = cliente.GetDatabase(opciones.Value.BaseDatos);

    /// <summary>La carga el pipeline de Python; la API la lee y el admin agrega libros.</summary>
    public IMongoCollection<Libro> Libros => bd.GetCollection<Libro>("Libros");

    public IMongoCollection<Usuario> Usuarios => bd.GetCollection<Usuario>("Usuarios");

    public IMongoCollection<SesionRefresco> Sesiones => bd.GetCollection<SesionRefresco>("Sesiones");
}

public sealed class OpcionesMongo
{
    /// <summary>Viene de MONGO_URI (el .env de la raíz), igual que en los scripts de Python.</summary>
    public string Uri { get; set; } = "";

    public string BaseDatos { get; set; } = "Biblioteca_Ingenieria";
}

public static class ServiciosBaseDatos
{
    public static IServiceCollection AddBaseDatos(this IServiceCollection servicios)
    {
        RegistrarConvenciones();

        servicios.AddOptions<OpcionesMongo>()
            .Configure<IConfiguration>((opciones, config) =>
            {
                opciones.Uri = config["MONGO_URI"] ?? "";
                opciones.BaseDatos = config["Mongo:BaseDatos"] ?? opciones.BaseDatos;
            })
            .Validate(opciones => opciones.Uri.Length > 0, "Falta MONGO_URI en el .env de la raíz del proyecto (o en las variables de entorno).")
            .ValidateOnStart();

        servicios.AddSingleton<IMongoClient>(sp =>
        {
            var ajustes = MongoClientSettings.FromConnectionString(sp.GetRequiredService<IOptions<OpcionesMongo>>().Value.Uri);
            ajustes.ServerSelectionTimeout = TimeSpan.FromSeconds(8);
            return new MongoClient(ajustes);
        });
        servicios.AddSingleton<BaseDatos>();
        servicios.AddHostedService<InicializadorIndices>();
        return servicios;
    }

    static int convencionesRegistradas;

    /// <summary>
    /// Las clases de C# usan PascalCase y los documentos snake_case (como modelo_libro.json): Paginas -> paginas,
    /// CaracteresTotales -> caracteres_totales. Los campos que el código no conoce se ignoran y los nulos no se guardan.
    /// </summary>
    static void RegistrarConvenciones()
    {
        if (Interlocked.Exchange(ref convencionesRegistradas, 1) == 1) return;

        var paquete = new ConventionPack
        {
            new SnakeCase(),
            new IgnoreExtraElementsConvention(true),
            new IgnoreIfNullConvention(true),
        };
        ConventionRegistry.Register("biblioteca", paquete, tipo => tipo.Namespace?.StartsWith("Biblioteca.Api", StringComparison.Ordinal) == true);
    }

    sealed class SnakeCase() : ConventionBase("SnakeCase"), IMemberMapConvention
    {
        public void Apply(BsonMemberMap mapa)
        {
            // Id ya lo mapea el driver a _id.
            if (mapa.MemberName != "Id") mapa.SetElementName(JsonNamingPolicy.SnakeCaseLower.ConvertName(mapa.MemberName));
        }
    }
}

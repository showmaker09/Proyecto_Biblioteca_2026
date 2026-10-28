using Microsoft.AspNetCore.Http.HttpResults;

namespace Biblioteca.Api.Comun;

/// <summary>Junta los errores de validación de una solicitud con el formato de ValidationProblem: { campo: [mensajes] }.</summary>
public sealed class Errores
{
    readonly Dictionary<string, string[]> porCampo = [];

    public bool Hay => porCampo.Count > 0;

    public void Si(bool condicion, string campo, string mensaje)
    {
        if (condicion) porCampo[campo] = [.. porCampo.GetValueOrDefault(campo, []), mensaje];
    }

    public ValidationProblem Problema() => TypedResults.ValidationProblem(porCampo);
}

# Etapa 1: Compilación (.NET 10 SDK)
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Biblioteca.Api/Biblioteca.Api.csproj Biblioteca.Api/
RUN dotnet restore Biblioteca.Api/Biblioteca.Api.csproj

COPY Biblioteca.Api/ Biblioteca.Api/
RUN dotnet publish Biblioteca.Api/Biblioteca.Api.csproj -c Release -o /app/publish --no-restore

# Etapa 2: Ejecución (imagen ligera de ASP.NET Core 10)
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 10000

COPY --from=build /app/publish ./

# Render inyecta el puerto dinámico en la variable de entorno PORT (por defecto 10000).
CMD ["sh", "-c", "dotnet Biblioteca.Api.dll --urls http://0.0.0.0:${PORT:-10000}"]

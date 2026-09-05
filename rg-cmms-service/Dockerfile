FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
WORKDIR /src
COPY ["rg-cmms-service.csproj", "./"]
RUN dotnet restore "./rg-cmms-service.csproj"
COPY . .
RUN dotnet publish "rg-cmms-service.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8082
EXPOSE 8082
ENTRYPOINT ["dotnet", "rg-cmms-service.dll"]

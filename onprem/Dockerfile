FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /src
COPY . .

WORKDIR /src/DataLoader
RUN dotnet build
RUN dotnet publish -f net9.0 -c Release

FROM mcr.microsoft.com/dotnet/runtime:9.0 AS runtime
WORKDIR /app
COPY --from=build /src/DataLoader/bin/Release/net9.0/publish .
ENTRYPOINT ["dotnet", "taxi.dll"]

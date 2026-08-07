using Microsoft.EntityFrameworkCore;
using RgCmmsService.Data;
using RgCmmsService.Services;

var builder = WebApplication.CreateBuilder(args);

// Environment variable from Docker/Compose takes precedence
var connectionString = Environment.GetEnvironmentVariable("NEON_URL") 
    ?? builder.Configuration.GetConnectionString("DefaultConnection");

if (string.IsNullOrEmpty(connectionString))
{
    throw new InvalidOperationException("NEON_URL environment variable is required.");
}

// Neon provides libpq-style URLs (postgresql://user:pass@host/db?sslmode=require)
// but Npgsql requires a keyword-based connection string. Convert it.
var npgsqlConnectionString = ConvertLibpqUrl(connectionString);

// Add DB Context (Neon PostgreSQL)
builder.Services.AddDbContext<CmmsDbContext>(options =>
    options.UseNpgsql(npgsqlConnectionString));

// Add controllers
builder.Services.AddControllers();

// Add Background Service for PPM
builder.Services.AddHostedService<PpmBackgroundService>();

var app = builder.Build();

// Ensure DB is created/migrated at startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<CmmsDbContext>();
    db.Database.EnsureCreated();
}

app.MapControllers();

app.MapGet("/health", () => new { status = "ok", service = "cmms" });

// Bind to port 8082 if running without Docker, Docker will map to 8082
app.Run();

/// <summary>
/// Converts a libpq-style PostgreSQL URL into an Npgsql keyword connection string.
/// </summary>
static string ConvertLibpqUrl(string url)
{
    if (!url.StartsWith("postgresql://") && !url.StartsWith("postgres://"))
    {
        return url; // Already a keyword-based connection string
    }

    var uri = new Uri(url);
    var host = uri.Host;
    var port = uri.Port > 0 ? uri.Port : 5432;
    var database = uri.AbsolutePath.TrimStart('/');
    var userInfo = uri.UserInfo.Split(':');
    var username = userInfo[0];
    var password = userInfo.Length > 1 ? userInfo[1] : "";

    var sslMode = "Prefer";
    var queryParts = uri.Query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries);
    foreach (var part in queryParts)
    {
        var kv = part.Split('=', 2);
        if (kv.Length == 2 && kv[0] == "sslmode")
        {
            sslMode = kv[1] switch
            {
                "require" => "Require",
                "verify-ca" => "VerifyCA",
                "verify-full" => "VerifyFull",
                _ => "Prefer"
            };
        }
    }

    return $"Host={host};Port={port};Database={database};Username={Uri.UnescapeDataString(username)};" +
           $"Password={Uri.UnescapeDataString(password)};SSL Mode={sslMode};Trust Server Certificate=true;";
}
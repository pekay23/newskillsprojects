using Microsoft.EntityFrameworkCore;
using RgCmmsService.Data;

namespace RgCmmsService.Services;

public class PpmBackgroundService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<PpmBackgroundService> _logger;

    public PpmBackgroundService(IServiceProvider serviceProvider, ILogger<PpmBackgroundService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("PPM Background Service started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            _logger.LogInformation("Running PPM check sweep...");
            try
            {
                await CheckDuePpmsAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred during PPM check");
            }
            
            // Check once per hour (adjust to daily for production)
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }

    private async Task CheckDuePpmsAsync(CancellationToken stoppingToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<CmmsDbContext>();

        var today = DateTime.UtcNow.Date;
        
        // Find assets due for PPM
        var dueAssets = await context.Assets
            .Where(a => a.PpmFrequencyDays > 0 && a.NextPpmDate != null && a.NextPpmDate <= today)
            .ToListAsync(stoppingToken);

        foreach (var asset in dueAssets)
        {
            _logger.LogInformation($"Asset {asset.Id} ({asset.Name}) is due for PPM. Triggering WO generation via Redis.");
            
            // TODO: Inject IConnectionMultiplexer (Redis) and publish to "wo.create.ppm"
            
            // Schedule next PPM
            asset.LastPpmDate = today;
            asset.NextPpmDate = today.AddDays(asset.PpmFrequencyDays);
        }

        if (dueAssets.Any())
        {
            await context.SaveChangesAsync(stoppingToken);
        }
    }
}

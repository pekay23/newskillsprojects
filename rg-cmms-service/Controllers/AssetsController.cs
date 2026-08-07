using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RgCmmsService.Data;
using RgCmmsService.Models;

namespace RgCmmsService.Controllers;

[ApiController]
[Route("[controller]")]
public class AssetsController : ControllerBase
{
    private readonly CmmsDbContext _context;

    public AssetsController(CmmsDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Asset>>> GetAssets()
    {
        return await _context.Assets.ToListAsync();
    }

    [HttpPost]
    public async Task<ActionResult<Asset>> CreateAsset(Asset asset)
    {
        // For demo: Ensure a property exists if not provided
        if (asset.PropertyId == Guid.Empty)
        {
            var prop = await _context.Properties.FirstOrDefaultAsync();
            if (prop == null)
            {
                prop = new Property { Name = "Default Facility" };
                _context.Properties.Add(prop);
                await _context.SaveChangesAsync();
            }
            asset.PropertyId = prop.Id;
        }

        _context.Assets.Add(asset);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetAssets), new { id = asset.Id }, asset);
    }
}

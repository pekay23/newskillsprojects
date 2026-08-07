using Microsoft.EntityFrameworkCore;
using RgCmmsService.Models;

namespace RgCmmsService.Data;

public class CmmsDbContext : DbContext
{
    public CmmsDbContext(DbContextOptions<CmmsDbContext> options) : base(options) { }

    public DbSet<Property> Properties { get; set; }
    public DbSet<Asset> Assets { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("cmms");
        
        // Define relations
        modelBuilder.Entity<Asset>()
            .HasOne(a => a.Property)
            .WithMany(p => p.Assets)
            .HasForeignKey(a => a.PropertyId);
    }
}

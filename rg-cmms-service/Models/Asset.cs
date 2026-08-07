using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RgCmmsService.Models;

[Table("assets", Schema = "cmms")]
public class Asset
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();
    
    [Required]
    public string Name { get; set; } = string.Empty;
    
    public string Category { get; set; } = string.Empty;
    
    public Guid PropertyId { get; set; }
    public Property? Property { get; set; }
    
    // PPM Schedule in days (0 means no PPM)
    public int PpmFrequencyDays { get; set; } = 0;
    public DateTime? LastPpmDate { get; set; }
    public DateTime? NextPpmDate { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

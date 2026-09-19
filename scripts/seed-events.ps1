# Seeds sample events into event-service for local demo/testing.
# Requires event-service running and reachable (adjust $baseUrl as needed).

param(
    [string]$baseUrl = "http://localhost:8081"
)

$events = @(
    @{ name = "Rock Night Live"; date = "2026-11-15"; venue = "Cairo Arena"; totalSeats = 200; availableSeats = 200 },
    @{ name = "Jazz Under the Stars"; date = "2026-11-22"; venue = "Nile Palace"; totalSeats = 80; availableSeats = 80 },
    @{ name = "Tech Conference 2026"; date = "2026-12-05"; venue = "Cairo Convention Center"; totalSeats = 500; availableSeats = 500 },
    @{ name = "Comedy Show"; date = "2026-12-10"; venue = "Downtown Theatre"; totalSeats = 120; availableSeats = 120 },
    @{ name = "New Year Countdown Party"; date = "2026-12-31"; venue = "Cairo Arena"; totalSeats = 1000; availableSeats = 1000 }
)

foreach ($event in $events) {
    $body = $event | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Uri "$baseUrl/api/events" -Method Post -Body $body -ContentType "application/json"
        Write-Host "Created: $($result.name) (id=$($result.id))" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create: $($event.name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

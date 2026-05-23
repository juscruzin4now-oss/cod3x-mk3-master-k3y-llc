# 🌤️ COD3X Weather Dashboard

A modern, responsive weather dashboard that fetches real-time weather data from the Open-Meteo API.

## Features

✨ **Core Features:**
- 🌍 Real-time weather data for any city worldwide
- 📍 Geolocation support (get weather for your current location)
- 🌡️ Temperature unit toggle (Celsius/Fahrenheit)
- 📅 5-day weather forecast
- 📊 Detailed weather metrics (humidity, wind speed, pressure, etc.)
- 📱 Fully responsive design (mobile, tablet, desktop)
- 🎨 Beautiful gradient UI with smooth animations
- ⚡ No API key required (uses free Open-Meteo API)

## Tech Stack

- **HTML5** - Semantic markup
- **CSS3** - Modern styling with gradients and animations
- **Vanilla JavaScript** - No frameworks, lightweight and fast
- **Open-Meteo API** - Free weather data provider

## Installation

### Option 1: Run Locally

1. Clone or download this project
2. Navigate to the `weather-dashboard` directory
3. Open `index.html` in your web browser

That's it! No installation or configuration needed.

### Option 2: Deploy to GitHub Pages

1. Push the `weather-dashboard` folder to your GitHub repository
2. Go to repository Settings → Pages
3. Select `main` branch and `/weather-dashboard` folder
4. Your dashboard will be live at `https://yourusername.github.io/repo-name/weather-dashboard/`

## Usage

### Search by City
1. Type a city name in the search box
2. Press Enter or click the Search button
3. Weather data updates instantly

### Use Your Location
1. Click the "📍 My Location" button
2. Allow location permissions when prompted
3. Weather data loads for your current location

### Toggle Temperature Unit
- Click the "°C / °F" button to switch between Celsius and Fahrenheit
- All temperatures update automatically

## API Reference

### Open-Meteo API

The dashboard uses two endpoints from Open-Meteo (no authentication required):

**Geocoding API**
```
GET https://geocoding-api.open-meteo.com/v1/search?name={city}&count=1
```

**Weather API**
```
GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=...&daily=...
```

[Learn more about Open-Meteo](https://open-meteo.com/)

## File Structure

```
weather-dashboard/
├── index.html       # HTML structure
├── styles.css       # Styling and responsive design
├── app.js          # JavaScript logic and API calls
└── README.md       # Documentation
```

## Weather Codes

The dashboard uses WMO Weather Codes to interpret weather conditions:

| Code | Description | Icon |
|------|-------------|------|
| 0 | Clear sky | ☀️ |
| 1-2 | Mostly clear | 🌤️ |
| 3 | Overcast | ☁️ |
| 45-48 | Foggy | 🌫️ |
| 51-55 | Drizzle | 🌦️ |
| 61-65 | Rain | 🌧️ |
| 71-75 | Snow | ❄️ |
| 80-82 | Showers | ⛈️ |
| 85-86 | Snow showers | 🌨️ |
| 95-99 | Thunderstorm | ⚡ |

## Features Breakdown

### Current Weather Display
- Large temperature display
- Weather condition icon and description
- "Feels like" temperature
- Current date and time
- City name and location

### 5-Day Forecast
- Daily weather cards
- Max/min temperatures
- Weather icons
- Hover animation effects

### Weather Details
- Humidity percentage
- Wind speed (km/h or mph)
- Atmospheric pressure
- UV Index
- Visibility

### Responsive Design
- Mobile-first approach
- Tablet optimization
- Desktop layout
- Touch-friendly buttons

## Browser Compatibility

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile browsers (iOS Safari, Chrome Mobile)

## Performance

- Zero external dependencies
- Fast API response times
- Optimized CSS animations
- Efficient JavaScript code
- ~50KB total file size

## Future Enhancements

Potential features to add:
- ☀️ Sunrise/sunset times
- 🌊 Air quality index
- 📈 Historical weather data
- 📍 Multiple saved locations
- 🔔 Weather alerts
- 🌙 Dark mode toggle
- 📊 Weather charts and graphs
- 🌍 Map view with weather overlay

## Troubleshooting

### Weather data not loading
- Check your internet connection
- Verify the city name is spelled correctly
- Open browser console (F12) to see error messages

### Geolocation not working
- Enable location permissions in browser settings
- Some browsers require HTTPS (not localhost)
- Check privacy settings

### API errors
- Open-Meteo API is generally very reliable
- Check if your internet connection is stable
- Wait a moment and try again

## License

This project is part of COD3X MK3 - feel free to use, modify, and distribute.

## Credits

- **Open-Meteo** - Free weather and geocoding API
- **COD3X MK3** - Master Key implementation
- Built with 💙 for weather enthusiasts

## Support

For issues or suggestions:
1. Check the troubleshooting section
2. Open an issue in the repository
3. Review the browser console for error messages

---

**Happy forecasting!** 🌤️🌈

#!/usr/bin/env python3
"""
SProp Calculations Module
Contains utility functions for temperature and humidity control logic for orchid care
Simplified control logic based on flowchart:
- Temp > 24°C: Fan ON, Lid OPEN
- Temp < 18°C: Fan OFF, Lid CLOSED
- Humidity > 70%: Fan ON, Lid OPEN, Valve CLOSED
- Humidity < 40%: Fan OFF, Lid CLOSED, Valve OPEN
- Default (18-24°C and 40-70%): Fan OFF, Lid CLOSED
"""
from typing import Dict


def get_combined_control_recommendation(temp: float, humidity: float) -> Dict[str, any]:
    """
    Get combined control recommendations based on both temperature and humidity.
    
    Simplified decision tree logic:
    1. If Temp > 24°C: Fan ON, Lid OPEN
    2. Else if Temp < 18°C: Fan OFF, Lid CLOSED
    3. Else if Humidity > 70%: Fan ON, Lid OPEN, Valve CLOSED
    4. Else if Humidity < 40%: Fan OFF, Lid CLOSED, Valve OPEN
    5. Else (18-24°C and 40-70%): Fan OFF, Lid CLOSED
    
    Args:
        temp: Current temperature in Celsius
        humidity: Current humidity percentage
    
    Returns:
        Dictionary with final control recommendations:
        - fan_action: "ON" or "OFF"
        - lid_action: "OPEN" or "CLOSED"
        - valve_action: "OPEN" or "CLOSED" (or None if not specified)
        - message: Status message
    """
    # Decision 1: Temperature > 24°C
    if temp > 24.0:
        return {
            "fan_action": "ON",
            "lid_action": "OPEN",
            "valve_action": None,
            "message": f"Temperature {temp:.1f}°C > 24°C - Cooling: Fan ON, Lid OPEN"
        }
    
    # Decision 2: Temperature < 18°C
    if temp < 18.0:
        return {
            "fan_action": "OFF",
            "lid_action": "CLOSED",
            "valve_action": None,
            "message": f"Temperature {temp:.1f}°C < 18°C - Heating: Fan OFF, Lid CLOSED"
        }
    
    # Decision 3: Humidity > 70%
    if humidity > 70.0:
        return {
            "fan_action": "ON",
            "lid_action": "OPEN",
            "valve_action": "CLOSED",
            "message": f"Humidity {humidity:.1f}% > 70% - Dehumidify: Fan ON, Lid OPEN, Valve CLOSED"
        }
    
    # Decision 4: Humidity < 40%
    if humidity < 40.0:
        return {
            "fan_action": "OFF",
            "lid_action": "CLOSED",
            "valve_action": "OPEN",
            "message": f"Humidity {humidity:.1f}% < 40% - Add moisture: Fan OFF, Lid CLOSED, Valve OPEN"
        }
    
    # Default: Optimal conditions (18-24°C and 40-70%)
    return {
        "fan_action": "OFF",
        "lid_action": "CLOSED",
        "valve_action": None,
        "message": f"Optimal conditions: Temp {temp:.1f}°C (18-24°C), Humidity {humidity:.1f}% (40-70%) - Fan OFF, Lid CLOSED"
    }

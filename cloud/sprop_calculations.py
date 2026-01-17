#!/usr/bin/env python3
"""
SProp Calculations Module
Contains utility functions for temperature and humidity control logic for orchid care
"""
from typing import Dict, Optional


def check_temperature_control(temp: float, optimal_min: float = 18.0, optimal_max: float = 24.0) -> Dict[str, any]:
    """
    Determine temperature control actions for orchid care.
    
    Ideal Range: 18-24°C (65-75°F) during the day is perfect for many common orchids
    like Phalaenopsis, Cattleya, and Dendrobium.
    Avoid extremes: Keep away from drafts, air conditioning vents, and direct heat sources.
    
    Args:
        temp: Current temperature in Celsius
        optimal_min: Minimum optimal temperature (default: 18°C / 65°F)
        optimal_max: Maximum optimal temperature (default: 24°C / 75°F)
    
    Returns:
        Dictionary with control recommendations:
        - fan_action: "ON", "OFF", or None (no change needed)
        - lid_action: "OPEN", "CLOSED", or None
        - status: "optimal", "too_low", "too_high", "critical_high", "critical_low"
        - message: Human-readable status message
    """
    # Critical high temperature - emergency cooling required
    if temp > 30.0:
        return {
            "fan_action": "ON",
            "lid_action": "OPEN",
            "status": "critical_high",
            "message": f"Critical: Temperature {temp:.1f}°C ({temp*9/5+32:.1f}°F) exceeds 30°C (86°F) - Emergency cooling required"
        }
    
    # Critical low temperature - emergency heating required
    if temp < 10.0:
        return {
            "fan_action": "OFF",
            "lid_action": "CLOSED",
            "status": "critical_low",
            "message": f"Critical: Temperature {temp:.1f}°C ({temp*9/5+32:.1f}°F) below 10°C (50°F) - Emergency heating required"
        }
    
    # Too high - need cooling
    if temp > optimal_max:
        return {
            "fan_action": "ON",
            "lid_action": "OPEN",
            "status": "too_high",
            "message": f"Temperature {temp:.1f}°C ({temp*9/5+32:.1f}°F) above optimal range (18-24°C / 65-75°F) - Cooling needed"
        }
    
    # Too low - need heating (close lid, turn off fan)
    if temp < optimal_min:
        return {
            "fan_action": "OFF",
            "lid_action": "CLOSED",
            "status": "too_low",
            "message": f"Temperature {temp:.1f}°C ({temp*9/5+32:.1f}°F) below optimal range (18-24°C / 65-75°F) - Heating needed"
        }
    
    # Optimal range
    return {
        "fan_action": None,  # Maintain current state
        "lid_action": None,   # Maintain current state
        "status": "optimal",
        "message": f"Temperature {temp:.1f}°C ({temp*9/5+32:.1f}°F) within optimal range (18-24°C / 65-75°F)"
    }


def check_humidity_control(humidity: float, optimal_min: float = 40.0, optimal_max: float = 70.0) -> Dict[str, any]:
    """
    Determine humidity control actions for orchid care.
    
    Target Levels: 40-70% relative humidity; many orchids prefer the higher end.
    This range is ideal for most common orchids like Phalaenopsis, Cattleya, and Dendrobium.
    
    Args:
        humidity: Current humidity percentage
        optimal_min: Minimum optimal humidity (default: 40%)
        optimal_max: Maximum optimal humidity (default: 70%)
    
    Returns:
        Dictionary with control recommendations:
        - fan_action: "ON", "OFF", or None (no change needed)
        - lid_action: "OPEN", "CLOSED", or None (for high humidity)
        - status: "optimal", "too_low", "too_high"
        - message: Human-readable status message
    """
    # Too high - need dehumidification (fan on, lid open)
    if humidity > optimal_max:
        return {
            "fan_action": "ON",
            "lid_action": "OPEN",  # Open lid to help reduce humidity
            "status": "too_high",
            "message": f"Humidity {humidity:.1f}% above optimal range (40-70%) - Dehumidification needed (Fan ON, Lid OPEN)"
        }
    
    # Too low - need moisture (fan off to retain moisture, lid closed)
    if humidity < optimal_min:
        return {
            "fan_action": "OFF",
            "lid_action": "CLOSED",  # Close lid to retain moisture
            "status": "too_low",
            "message": f"Humidity {humidity:.1f}% below optimal range (40-70%) - Moisture retention needed"
        }
    
    # Optimal range - close lid to maintain optimal conditions
    # (lid was opened for dehumidification, now close it)
    return {
        "fan_action": None,  # Maintain current state (fan may be on for temp control)
        "lid_action": "CLOSED",  # Close lid when humidity returns to optimal
        "status": "optimal",
        "message": f"Humidity {humidity:.1f}% within optimal range (40-70%) - Conditions ideal for orchids"
    }


def get_combined_control_recommendation(temp: float, humidity: float) -> Dict[str, any]:
    """
    Get combined control recommendations based on both temperature and humidity for orchid care.
    
    Priority Logic:
    1. Critical temperature extremes take priority - emergency response
       - Critical high (>30°C / 86°F): Emergency cooling
       - Critical low (<10°C / 50°F): Emergency heating
    2. Critical humidity (>70%) takes priority - must reduce humidity even if temp is low
    3. Normal temperature control (18-24°C / 65-75°F optimal)
    4. Normal humidity control (40-70% optimal, prefer higher end)
    
    For conflicting cases (low temp + high humidity):
    - If temp > 30°C or < 10°C: Temperature takes absolute priority
    - If humidity > 70%: Prioritize humidity control (fan ON, lid OPEN)
    - Otherwise: Temperature takes priority
    
    Args:
        temp: Current temperature in Celsius
        humidity: Current humidity percentage
    
    Returns:
        Dictionary with final control recommendations:
        - fan_action: "ON", "OFF", or None
        - lid_action: "OPEN", "CLOSED", or None
        - temp_status: Temperature status
        - humidity_status: Humidity status
        - message: Combined status message
    """
    temp_control = check_temperature_control(temp)
    humidity_control = check_humidity_control(humidity)
    
    # Critical temperature extremes take absolute priority
    if temp > 30.0 or temp < 10.0:
        # Emergency temperature control - temperature takes absolute priority
        fan_action = temp_control["fan_action"]
        lid_action = temp_control["lid_action"]
    # Critical humidity (>70%) takes priority - must reduce humidity
    elif humidity > 70.0:
        # High humidity is critical - prioritize humidity control
        # Fan ON and Lid OPEN to reduce humidity, even if temp is low
        fan_action = humidity_control["fan_action"]  # Should be "ON"
        lid_action = humidity_control["lid_action"]  # Should be "OPEN"
    # Normal priority: Temperature > Humidity
    else:
        # Standard priority: Temperature takes priority
        if temp_control["fan_action"] is not None:
            fan_action = temp_control["fan_action"]
        else:
            fan_action = humidity_control["fan_action"]
        
        if temp_control["lid_action"] is not None:
            lid_action = temp_control["lid_action"]  # Temperature takes priority
        else:
            lid_action = humidity_control["lid_action"]  # Use humidity control (will be "CLOSED" when optimal)
        
        # If both temp and humidity are optimal, ensure lid is closed and fan is off
        # This handles edge cases where both return None
        if (temp_control["status"] == "optimal" and 
            humidity_control["status"] == "optimal"):
            if lid_action is None:
                lid_action = "CLOSED"  # Close lid when conditions are optimal
            if fan_action is None:
                fan_action = "OFF"  # Turn off fan when conditions are optimal
    
    # Combine messages
    messages = [temp_control["message"], humidity_control["message"]]
    
    return {
        "fan_action": fan_action,
        "lid_action": lid_action,
        "temp_status": temp_control["status"],
        "humidity_status": humidity_control["status"],
        "temp_message": temp_control["message"],
        "humidity_message": humidity_control["message"],
        "message": " | ".join(messages)
    }

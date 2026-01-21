"""
Calculation utilities for 5/3/1 program.
"""
from typing import List, Dict


def calculate_1rm(weight: float, reps: int) -> float:
    """
    Calculate one-rep max using Epley formula.

    Formula: 1RM = weight × (1 + reps/30)

    Args:
        weight: The weight lifted
        reps: Number of reps completed

    Returns:
        Calculated 1RM
    """
    if reps == 1:
        return weight
    return weight * (1 + reps / 30)


def calculate_training_max(one_rm: float) -> float:
    """
    Calculate training max as 90% of 1RM per Jim Wendler.

    Args:
        one_rm: The one-rep max

    Returns:
        Training max (90% of 1RM)
    """
    return one_rm * 0.90


def calculate_working_weight(
    training_max: float,
    week: int,
    set_number: int,
    rounding_increment: float = 5.0
) -> float:
    """
    Calculate working weight for a given week and set.

    Week 1 (5s): 65%, 75%, 85%
    Week 2 (3s): 70%, 80%, 90%
    Week 3 (5/3/1): 75%, 85%, 95%
    Week 4 (Deload): 40%, 50%, 60%

    Args:
        training_max: The training max for the lift
        week: Week number (1-4)
        set_number: Set number (1-3)
        rounding_increment: How to round the weight (default: 5.0)

    Returns:
        Calculated and rounded working weight
    """
    percentages = {
        1: [0.65, 0.75, 0.85],  # Week 1
        2: [0.70, 0.80, 0.90],  # Week 2
        3: [0.75, 0.85, 0.95],  # Week 3
        4: [0.40, 0.50, 0.60],  # Week 4 (deload)
    }

    percentage = percentages[week][set_number - 1]
    raw_weight = training_max * percentage

    # Round to nearest increment
    return round(raw_weight / rounding_increment) * rounding_increment


def get_prescribed_reps(week: int, set_number: int) -> int:
    """
    Get prescribed reps for a given week and set.

    Args:
        week: Week number (1-4)
        set_number: Set number (1-3)

    Returns:
        Number of prescribed reps
    """
    reps_scheme = {
        1: [5, 5, 5],  # Week 1: 5/5/5+
        2: [3, 3, 3],  # Week 2: 3/3/3+
        3: [5, 3, 1],  # Week 3: 5/3/1+
        4: [5, 5, 5],  # Week 4 (deload): 5/5/5
    }

    return reps_scheme[week][set_number - 1]


def calculate_warmup_weights(
    training_max: float,
    rounding_increment: float = 5.0,
    bar_weight: float = 45.0
) -> List[Dict]:
    """
    Calculate standard 5/3/1 warmup progression.

    Standard warmup per Jim Wendler:
    - Empty bar × 5
    - 40% × 5
    - 50% × 5
    - 60% × 3

    Args:
        training_max: The training max for the lift
        rounding_increment: How to round weights
        bar_weight: Weight of the barbell

    Returns:
        List of warmup sets with weight and reps
    """
    warmups = [
        {"percentage": 0.0, "reps": 5},    # Empty bar
        {"percentage": 0.40, "reps": 5},   # 40%
        {"percentage": 0.50, "reps": 5},   # 50%
        {"percentage": 0.60, "reps": 3},   # 60%
    ]

    result = []
    for warmup in warmups:
        if warmup["percentage"] == 0.0:
            weight = bar_weight
        else:
            raw_weight = training_max * warmup["percentage"]
            weight = round(raw_weight / rounding_increment) * rounding_increment

        result.append({
            "weight": weight,
            "reps": warmup["reps"],
            "percentage": warmup["percentage"]
        })

    return result


def calculate_plates(
    target_weight: float,
    bar_weight: float = 45.0,
    available_plates: List[float] = None
) -> List[float]:
    """
    Calculate which plates to load per side of bar.
    Uses greedy algorithm to minimize number of plates.

    Args:
        target_weight: Target weight to load
        bar_weight: Weight of the barbell
        available_plates: List of available plate weights

    Returns:
        List of plates to load on one side
    """
    if available_plates is None:
        # TODO: Make available plates configurable per user
        available_plates = [45, 35, 25, 10, 5, 2.5, 1.0, 0.75, 0.5, 0.25]

    weight_per_side = (target_weight - bar_weight) / 2

    if weight_per_side <= 0:
        return []

    plates = []
    remaining = weight_per_side

    for plate in sorted(available_plates, reverse=True):
        while remaining >= plate:
            plates.append(plate)
            remaining -= plate

    return plates


def format_plate_display(plates: List[float]) -> str:
    """
    Format plates for display: "45 + 25 + 10 per side"

    Args:
        plates: List of plates

    Returns:
        Formatted string
    """
    if not plates:
        return "Bar only"

    plate_str = " + ".join(str(int(p) if p == int(p) else p) for p in plates)
    return f"{plate_str} per side"

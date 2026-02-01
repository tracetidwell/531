"""
Unit tests for calculation utilities.
"""
import pytest
from app.utils.calculations import (
    calculate_1rm,
    calculate_training_max,
    calculate_working_weight,
    get_prescribed_reps,
    calculate_warmup_weights,
    calculate_plates,
    format_plate_display
)


class TestCalculate1RM:
    """Tests for one-rep max calculation using Epley formula."""

    def test_1rm_single_rep(self):
        """Test 1RM for single rep equals the weight."""
        assert calculate_1rm(315, 1) == 315

    def test_1rm_five_reps(self):
        """Test 1RM calculation for 5 reps."""
        # Epley: 225 * (1 + 5/30) = 225 * 1.1667 = 262.5
        result = calculate_1rm(225, 5)
        assert result == pytest.approx(262.5, rel=0.01)

    def test_1rm_ten_reps(self):
        """Test 1RM calculation for 10 reps."""
        # Epley: 200 * (1 + 10/30) = 200 * 1.333 = 266.67
        result = calculate_1rm(200, 10)
        assert result == pytest.approx(266.67, rel=0.01)

    def test_1rm_three_reps(self):
        """Test 1RM calculation for 3 reps."""
        # Epley: 275 * (1 + 3/30) = 275 * 1.10 = 302.5
        result = calculate_1rm(275, 3)
        assert result == pytest.approx(302.5, rel=0.01)

    def test_1rm_light_weight_high_reps(self):
        """Test 1RM with light weight and high reps."""
        # Epley: 135 * (1 + 12/30) = 135 * 1.40 = 189
        result = calculate_1rm(135, 12)
        assert result == pytest.approx(189, rel=0.01)


class TestCalculateTrainingMax:
    """Tests for training max calculation (90% of 1RM)."""

    def test_training_max_calculation(self):
        """Test training max is 90% of 1RM."""
        assert calculate_training_max(300) == 270
        assert calculate_training_max(400) == 360
        assert calculate_training_max(225) == 202.5


class TestCalculateWorkingWeight:
    """Tests for working weight calculation."""

    def test_week1_percentages(self):
        """Test week 1 uses 65%, 75%, 85% percentages."""
        tm = 300
        # 65% of 300 = 195
        assert calculate_working_weight(tm, 1, 1) == 195
        # 75% of 300 = 225
        assert calculate_working_weight(tm, 1, 2) == 225
        # 85% of 300 = 255
        assert calculate_working_weight(tm, 1, 3) == 255

    def test_week2_percentages(self):
        """Test week 2 uses 70%, 80%, 90% percentages."""
        tm = 300
        # 70% of 300 = 210
        assert calculate_working_weight(tm, 2, 1) == 210
        # 80% of 300 = 240
        assert calculate_working_weight(tm, 2, 2) == 240
        # 90% of 300 = 270
        assert calculate_working_weight(tm, 2, 3) == 270

    def test_week3_percentages(self):
        """Test week 3 uses 75%, 85%, 95% percentages."""
        tm = 300
        # 75% of 300 = 225
        assert calculate_working_weight(tm, 3, 1) == 225
        # 85% of 300 = 255
        assert calculate_working_weight(tm, 3, 2) == 255
        # 95% of 300 = 285
        assert calculate_working_weight(tm, 3, 3) == 285

    def test_week4_deload_percentages(self):
        """Test week 4 (deload) uses 40%, 50%, 60% percentages."""
        tm = 300
        # 40% of 300 = 120
        assert calculate_working_weight(tm, 4, 1) == 120
        # 50% of 300 = 150
        assert calculate_working_weight(tm, 4, 2) == 150
        # 60% of 300 = 180
        assert calculate_working_weight(tm, 4, 3) == 180

    def test_rounding_to_5_lbs(self):
        """Test weight is rounded to nearest 5 lbs by default."""
        tm = 250  # 65% = 162.5, rounds to 160 (banker's rounding)
        assert calculate_working_weight(tm, 1, 1) == 160

    def test_custom_rounding_increment(self):
        """Test custom rounding increment."""
        tm = 250  # 65% = 162.5
        # Rounds to 162.5 with 2.5 increment
        assert calculate_working_weight(tm, 1, 1, rounding_increment=2.5) == 162.5


class TestGetPrescribedReps:
    """Tests for prescribed reps by week and set."""

    def test_week1_reps(self):
        """Test week 1 is 5/5/5+."""
        assert get_prescribed_reps(1, 1) == 5
        assert get_prescribed_reps(1, 2) == 5
        assert get_prescribed_reps(1, 3) == 5

    def test_week2_reps(self):
        """Test week 2 is 3/3/3+."""
        assert get_prescribed_reps(2, 1) == 3
        assert get_prescribed_reps(2, 2) == 3
        assert get_prescribed_reps(2, 3) == 3

    def test_week3_reps(self):
        """Test week 3 is 5/3/1+."""
        assert get_prescribed_reps(3, 1) == 5
        assert get_prescribed_reps(3, 2) == 3
        assert get_prescribed_reps(3, 3) == 1

    def test_week4_deload_reps(self):
        """Test week 4 (deload) is 5/5/5."""
        assert get_prescribed_reps(4, 1) == 5
        assert get_prescribed_reps(4, 2) == 5
        assert get_prescribed_reps(4, 3) == 5


class TestCalculateWarmupWeights:
    """Tests for warmup weight calculation."""

    def test_warmup_set_count(self):
        """Test warmup generates 4 sets."""
        result = calculate_warmup_weights(300)
        assert len(result) == 4

    def test_warmup_first_set_bar_only(self):
        """Test first warmup set is bar weight."""
        result = calculate_warmup_weights(300, bar_weight=45)
        assert result[0]["weight"] == 45
        assert result[0]["reps"] == 5
        assert result[0]["percentage"] == 0.0

    def test_warmup_percentages(self):
        """Test warmup uses 40%, 50%, 60% after bar."""
        result = calculate_warmup_weights(300)
        assert result[1]["percentage"] == 0.40
        assert result[2]["percentage"] == 0.50
        assert result[3]["percentage"] == 0.60

    def test_warmup_weight_calculation(self):
        """Test warmup weights are calculated correctly."""
        tm = 300
        result = calculate_warmup_weights(tm, rounding_increment=5)
        # 40% of 300 = 120
        assert result[1]["weight"] == 120
        # 50% of 300 = 150
        assert result[2]["weight"] == 150
        # 60% of 300 = 180
        assert result[3]["weight"] == 180

    def test_warmup_reps(self):
        """Test warmup rep scheme is 5/5/5/3."""
        result = calculate_warmup_weights(300)
        assert result[0]["reps"] == 5
        assert result[1]["reps"] == 5
        assert result[2]["reps"] == 5
        assert result[3]["reps"] == 3

    def test_warmup_custom_bar_weight(self):
        """Test warmup with different bar weight."""
        result = calculate_warmup_weights(300, bar_weight=35)
        assert result[0]["weight"] == 35


class TestCalculatePlates:
    """Tests for plate calculation."""

    def test_empty_bar(self):
        """Test calculating plates for bar weight returns empty list."""
        plates = calculate_plates(45, bar_weight=45)
        assert plates == []

    def test_basic_plate_calculation(self):
        """Test basic plate calculation."""
        # 135 lbs = 45 bar + 90 plates (45 per side)
        plates = calculate_plates(135, bar_weight=45)
        assert plates == [45]

    def test_multiple_plates(self):
        """Test calculation with multiple plates per side."""
        # 225 lbs = 45 bar + 180 plates (90 per side = 45 + 45)
        plates = calculate_plates(225, bar_weight=45)
        assert plates == [45, 45]

    def test_mixed_plate_sizes(self):
        """Test calculation requiring different plate sizes."""
        # 185 lbs = 45 bar + 140 plates (70 per side = 45 + 25)
        plates = calculate_plates(185, bar_weight=45)
        assert plates == [45, 25]

    def test_small_plates(self):
        """Test calculation requiring small plates."""
        # 95 lbs = 45 bar + 50 plates (25 per side)
        plates = calculate_plates(95, bar_weight=45)
        assert plates == [25]

    def test_weight_less_than_bar(self):
        """Test target weight less than bar returns empty."""
        plates = calculate_plates(40, bar_weight=45)
        assert plates == []

    def test_fractional_plates(self):
        """Test calculation with fractional plates."""
        # 50 lbs = 45 bar + 5 plates (2.5 per side)
        plates = calculate_plates(50, bar_weight=45)
        assert plates == [2.5]


class TestFormatPlateDisplay:
    """Tests for plate display formatting."""

    def test_empty_plates(self):
        """Test formatting empty plate list."""
        result = format_plate_display([])
        assert result == "Bar only"

    def test_single_plate(self):
        """Test formatting single plate."""
        result = format_plate_display([45])
        assert result == "45 per side"

    def test_multiple_plates(self):
        """Test formatting multiple plates."""
        result = format_plate_display([45, 25])
        assert result == "45 + 25 per side"

    def test_fractional_plates(self):
        """Test formatting fractional plates."""
        result = format_plate_display([45, 2.5])
        assert result == "45 + 2.5 per side"

    def test_many_plates(self):
        """Test formatting many plates."""
        result = format_plate_display([45, 45, 25, 10, 5])
        assert result == "45 + 45 + 25 + 10 + 5 per side"

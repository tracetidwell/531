"""
Tests for warmup template CRUD endpoints.
"""


class TestListWarmupTemplates:
    """Tests for GET /api/v1/warmup-templates endpoint."""

    def test_list_warmup_templates_empty(self, client, auth_headers, test_user):
        """Test listing warmup templates when none exist."""
        response = client.get("/api/v1/warmup-templates", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_list_warmup_templates_filter_by_lift(
        self, client, auth_headers, test_user
    ):
        """Test filtering warmup templates by lift type."""
        # First create a template
        template_data = {
            "name": "Test Squat Warmup",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": [
                {"weight_type": "bar", "value": None, "reps": 10},
                {"weight_type": "percentage", "value": 50, "reps": 5}
            ]
        }
        client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )

        # Filter by squat
        response = client.get(
            "/api/v1/warmup-templates",
            params={"lift_type": "SQUAT"},
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        for template in data:
            assert template["lift_type"] == "SQUAT"

    def test_list_warmup_templates_unauthorized(self, client):
        """Test listing warmup templates without auth returns 403."""
        response = client.get("/api/v1/warmup-templates")
        assert response.status_code == 403


class TestCreateWarmupTemplate:
    """Tests for POST /api/v1/warmup-templates endpoint."""

    def test_create_warmup_template_success(self, client, auth_headers, test_user):
        """Test creating a warmup template."""
        template_data = {
            "name": "My Squat Warmup",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": [
                {"weight_type": "bar", "value": None, "reps": 10},
                {"weight_type": "fixed", "value": 135, "reps": 5},
                {"weight_type": "percentage", "value": 50, "reps": 5},
                {"weight_type": "percentage", "value": 70, "reps": 3}
            ]
        }
        response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "My Squat Warmup"
        assert data["lift_type"] == "SQUAT"
        assert len(data["sets"]) == 4

    def test_create_warmup_template_bar_weight(
        self, client, auth_headers, test_user
    ):
        """Test creating template with bar weight type."""
        template_data = {
            "name": "Bar Only Warmup",
            "lift_type": "BENCH_PRESS",
            "is_default": False,
            "sets": [
                {"weight_type": "bar", "value": None, "reps": 20}
            ]
        }
        response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        assert response.status_code == 201
        data = response.json()
        assert data["sets"][0]["weight_type"] == "bar"
        assert data["sets"][0]["value"] is None

    def test_create_warmup_template_fixed_weight(
        self, client, auth_headers, test_user
    ):
        """Test creating template with fixed weight type."""
        template_data = {
            "name": "Fixed Weight Warmup",
            "lift_type": "DEADLIFT",
            "is_default": False,
            "sets": [
                {"weight_type": "fixed", "value": 135, "reps": 5},
                {"weight_type": "fixed", "value": 225, "reps": 3}
            ]
        }
        response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        assert response.status_code == 201
        data = response.json()
        assert data["sets"][0]["weight_type"] == "fixed"
        assert data["sets"][0]["value"] == 135

    def test_create_warmup_template_percentage(
        self, client, auth_headers, test_user
    ):
        """Test creating template with percentage weight type."""
        template_data = {
            "name": "Percentage Warmup",
            "lift_type": "PRESS",
            "is_default": False,
            "sets": [
                {"weight_type": "percentage", "value": 40, "reps": 5},
                {"weight_type": "percentage", "value": 60, "reps": 3}
            ]
        }
        response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        assert response.status_code == 201
        data = response.json()
        assert data["sets"][0]["weight_type"] == "percentage"
        assert data["sets"][0]["value"] == 40

    def test_create_warmup_template_as_default(
        self, client, auth_headers, test_user
    ):
        """Test creating template as default for lift."""
        template_data = {
            "name": "Default Squat Warmup",
            "lift_type": "SQUAT",
            "is_default": True,
            "sets": [
                {"weight_type": "bar", "value": None, "reps": 10}
            ]
        }
        response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        assert response.status_code == 201
        data = response.json()
        assert data["is_default"] is True

    def test_create_warmup_template_empty_sets_fails(
        self, client, auth_headers, test_user
    ):
        """Test creating template with no sets fails validation."""
        template_data = {
            "name": "Empty Template",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": []
        }
        response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        assert response.status_code == 422

    def test_create_warmup_template_invalid_percentage(
        self, client, auth_headers, test_user
    ):
        """Test creating template with invalid percentage fails."""
        template_data = {
            "name": "Invalid Template",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": [
                {"weight_type": "percentage", "value": 150, "reps": 5}  # > 100%
            ]
        }
        response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        assert response.status_code == 422

    def test_create_warmup_template_unauthorized(self, client):
        """Test creating warmup template without auth returns 403."""
        template_data = {
            "name": "Test",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": [{"weight_type": "bar", "value": None, "reps": 5}]
        }
        response = client.post("/api/v1/warmup-templates", json=template_data)
        assert response.status_code == 403


class TestGetWarmupTemplate:
    """Tests for GET /api/v1/warmup-templates/{template_id} endpoint."""

    def test_get_warmup_template_success(self, client, auth_headers, test_user):
        """Test getting a specific warmup template."""
        # First create a template
        template_data = {
            "name": "Test Template",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": [{"weight_type": "bar", "value": None, "reps": 10}]
        }
        create_response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        template_id = create_response.json()["id"]

        # Get the template
        response = client.get(
            f"/api/v1/warmup-templates/{template_id}",
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == template_id
        assert data["name"] == "Test Template"

    def test_get_warmup_template_not_found(self, client, auth_headers, test_user):
        """Test getting non-existent template returns 404."""
        response = client.get(
            "/api/v1/warmup-templates/nonexistent-id",
            headers=auth_headers
        )
        assert response.status_code == 404


class TestUpdateWarmupTemplate:
    """Tests for PUT /api/v1/warmup-templates/{template_id} endpoint."""

    def test_update_warmup_template_success(self, client, auth_headers, test_user):
        """Test updating a warmup template."""
        # Create template
        template_data = {
            "name": "Original Name",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": [{"weight_type": "bar", "value": None, "reps": 10}]
        }
        create_response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        template_id = create_response.json()["id"]

        # Update template
        updated_data = {
            "name": "Updated Name",
            "lift_type": "SQUAT",
            "is_default": True,
            "sets": [
                {"weight_type": "bar", "value": None, "reps": 5},
                {"weight_type": "percentage", "value": 50, "reps": 5}
            ]
        }
        response = client.put(
            f"/api/v1/warmup-templates/{template_id}",
            json=updated_data,
            headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Name"
        assert data["is_default"] is True
        assert len(data["sets"]) == 2

    def test_update_warmup_template_not_found(self, client, auth_headers, test_user):
        """Test updating non-existent template returns 404."""
        template_data = {
            "name": "Test",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": [{"weight_type": "bar", "value": None, "reps": 5}]
        }
        response = client.put(
            "/api/v1/warmup-templates/nonexistent-id",
            json=template_data,
            headers=auth_headers
        )
        assert response.status_code == 404


class TestDeleteWarmupTemplate:
    """Tests for DELETE /api/v1/warmup-templates/{template_id} endpoint."""

    def test_delete_warmup_template_success(self, client, auth_headers, test_user):
        """Test deleting a warmup template."""
        # Create template
        template_data = {
            "name": "To Delete",
            "lift_type": "SQUAT",
            "is_default": False,
            "sets": [{"weight_type": "bar", "value": None, "reps": 10}]
        }
        create_response = client.post(
            "/api/v1/warmup-templates",
            json=template_data,
            headers=auth_headers
        )
        template_id = create_response.json()["id"]

        # Delete template
        response = client.delete(
            f"/api/v1/warmup-templates/{template_id}",
            headers=auth_headers
        )
        assert response.status_code == 204

        # Verify deleted
        get_response = client.get(
            f"/api/v1/warmup-templates/{template_id}",
            headers=auth_headers
        )
        assert get_response.status_code == 404

    def test_delete_warmup_template_not_found(self, client, auth_headers, test_user):
        """Test deleting non-existent template returns 404."""
        response = client.delete(
            "/api/v1/warmup-templates/nonexistent-id",
            headers=auth_headers
        )
        assert response.status_code == 404

    def test_delete_warmup_template_unauthorized(self, client):
        """Test deleting warmup template without auth returns 403."""
        response = client.delete("/api/v1/warmup-templates/some-id")
        assert response.status_code == 403

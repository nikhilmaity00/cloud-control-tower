import copy
import unittest

from control_tower.control_tower_validate import validate_deployment


BASE_DEPLOYMENT = {
    "application": {
        "name": "payments-api",
        "image": "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest",
    },
    "deployment": {
        "environment": "dev",
        "replicas": {
            "min": 1,
            "max": 1,
        },
    },
}


POLICY = {
    "environments": {
        "allowed": ["dev", "test", "prod"],
    },
    "replicas": {
        "min": {
            "allowed": [0, 1],
        },
        "max": {
            "allowed": [0, 1, 2],
        },
    },
    "application": {
        "name": {
            "pattern": r"^[a-z0-9][a-z0-9-]{2,29}$",
        },
    },
}


class TestDeploymentValidation(unittest.TestCase):

    # ---------------------------------------------------------
    # Existing policy tests
    # ---------------------------------------------------------

    def test_valid_deployment(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)

        errors = validate_deployment(deployment, POLICY)

        self.assertEqual(errors, [])

    def test_invalid_environment(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"]["environment"] = "production"

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("environment" in error for error in errors)
        )

    def test_max_replicas_exceeds_policy(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"]["replicas"]["max"] = 10

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("max" in error for error in errors)
        )

    def test_min_replicas_greater_than_max(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"]["replicas"]["min"] = 2

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("cannot be greater" in error for error in errors)
        )

    def test_invalid_application_name(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["application"]["name"] = "Payments_API"

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("application.name" in error for error in errors)
        )

    def test_missing_image(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        del deployment["application"]["image"]

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("image" in error for error in errors)
        )

    # ---------------------------------------------------------
    # Schema tests
    # ---------------------------------------------------------

    def test_unknown_top_level_field(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["owner"] = "platform-team"

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("Unknown top-level section" in error for error in errors)
        )

    def test_unknown_application_field(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["application"]["owner"] = "platform-team"

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("Unknown application field" in error for error in errors)
        )

    def test_unknown_deployment_field(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"]["region"] = "eastus"

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("Unknown deployment field" in error for error in errors)
        )

    def test_unknown_replica_field(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"]["replicas"]["desired"] = 1

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any(
                "Unknown deployment.replicas field" in error
                for error in errors
            )
        )

    def test_application_must_be_object(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["application"] = "payments-api"

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("application must be an object" in error for error in errors)
        )

    def test_deployment_must_be_object(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"] = "dev"

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any("deployment must be an object" in error for error in errors)
        )

    def test_replicas_must_be_object(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"]["replicas"] = 1

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any(
                "deployment.replicas must be an object"
                in error
                for error in errors
            )
        )

    def test_missing_application_name(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        del deployment["application"]["name"]

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any(
                "application.name is required"
                in error
                for error in errors
            )
        )

    def test_missing_replica_min(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        del deployment["deployment"]["replicas"]["min"]

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any(
                "deployment.replicas.min is required"
                in error
                for error in errors
            )
        )

    def test_boolean_replica_min_is_rejected(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"]["replicas"]["min"] = True

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any(
                "deployment.replicas.min must be an integer"
                in error
                for error in errors
            )
        )

    def test_boolean_replica_max_is_rejected(self):
        deployment = copy.deepcopy(BASE_DEPLOYMENT)
        deployment["deployment"]["replicas"]["max"] = False

        errors = validate_deployment(deployment, POLICY)

        self.assertTrue(
            any(
                "deployment.replicas.max must be an integer"
                in error
                for error in errors
            )
        )


if __name__ == "__main__":
    unittest.main()
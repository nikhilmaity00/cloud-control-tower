#!/usr/bin/env python3

import re
import sys
from pathlib import Path

import yaml


POLICY_FILE = Path(__file__).resolve().parent / "policy.yaml"


def load_yaml(path: Path) -> dict:
    """Load and return a YAML mapping."""
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    with path.open("r", encoding="utf-8") as file:
        data = yaml.safe_load(file)

    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a YAML object.")

    return data


def validate_deployment(deployment: dict, policy: dict) -> list[str]:
    """Validate deployment intent against platform policy."""

    errors = []

    application = deployment.get("application")
    deployment_config = deployment.get("deployment")

    # ---------------------------------------------------------
    # Required sections
    # ---------------------------------------------------------

    if not isinstance(application, dict):
        errors.append("application section is required.")
        application = {}

    if not isinstance(deployment_config, dict):
        errors.append("deployment section is required.")
        deployment_config = {}

    # ---------------------------------------------------------
    # Application name
    # ---------------------------------------------------------

    application_name = application.get("name")

    if not application_name:
        errors.append("application.name is required.")
    elif not isinstance(application_name, str):
        errors.append("application.name must be a string.")
    else:
        name_pattern = policy["application"]["name"]["pattern"]

        if not re.fullmatch(name_pattern, application_name):
            errors.append(
                f"application.name '{application_name}' does not "
                "match the platform naming policy."
            )

    # ---------------------------------------------------------
    # Container image
    # ---------------------------------------------------------

    image = application.get("image")

    if not image:
        errors.append("application.image is required.")
    elif not isinstance(image, str):
        errors.append("application.image must be a string.")

    # ---------------------------------------------------------
    # Environment
    # ---------------------------------------------------------

    environment = deployment_config.get("environment")

    allowed_environments = policy["environments"]["allowed"]

    if not environment:
        errors.append("deployment.environment is required.")
    elif environment not in allowed_environments:
        errors.append(
            f"deployment.environment '{environment}' is not allowed. "
            f"Allowed values: {', '.join(allowed_environments)}."
        )

    # ---------------------------------------------------------
    # Replicas
    # ---------------------------------------------------------

    replicas = deployment_config.get("replicas")

    if not isinstance(replicas, dict):
        errors.append("deployment.replicas section is required.")
        replicas = {}

    min_replicas = replicas.get("min")
    max_replicas = replicas.get("max")

    allowed_min = policy["replicas"]["min"]["allowed"]
    allowed_max = policy["replicas"]["max"]["allowed"]

    if min_replicas is None:
        errors.append("deployment.replicas.min is required.")
    elif not isinstance(min_replicas, int):
        errors.append("deployment.replicas.min must be an integer.")
    elif min_replicas not in allowed_min:
        errors.append(
            f"deployment.replicas.min '{min_replicas}' is not allowed. "
            f"Allowed values: {allowed_min}."
        )

    if max_replicas is None:
        errors.append("deployment.replicas.max is required.")
    elif not isinstance(max_replicas, int):
        errors.append("deployment.replicas.max must be an integer.")
    elif max_replicas not in allowed_max:
        errors.append(
            f"deployment.replicas.max '{max_replicas}' is not allowed. "
            f"Allowed values: {allowed_max}."
        )

    # ---------------------------------------------------------
    # Replica relationship
    # ---------------------------------------------------------

    if (
        isinstance(min_replicas, int)
        and isinstance(max_replicas, int)
        and min_replicas > max_replicas
    ):
        errors.append(
            "deployment.replicas.min cannot be greater than "
            "deployment.replicas.max."
        )

    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print(
            "Usage: python3 control-tower/validate.py "
            "<deployment.yaml>"
        )
        return 2

    deployment_path = Path(sys.argv[1])

    try:
        deployment = load_yaml(deployment_path)
        policy = load_yaml(POLICY_FILE)

        errors = validate_deployment(deployment, policy)

    except FileNotFoundError as exc:
        print("Deployment validation: ERROR")
        print(f"  {exc}")
        return 2

    except yaml.YAMLError as exc:
        print("Deployment validation: ERROR")
        print(f"  Invalid YAML: {exc}")
        return 2

    except (ValueError, KeyError) as exc:
        print("Deployment validation: ERROR")
        print(f"  {exc}")
        return 2

    if errors:
        print("Deployment validation: FAILED")
        print()

        for error in errors:
            print(f"  - {error}")

        return 1

    application = deployment["application"]
    deployment_config = deployment["deployment"]
    replicas = deployment_config["replicas"]

    print("Deployment validation: PASS")
    print()
    print(f"Application : {application['name']}")
    print(f"Environment : {deployment_config['environment']}")
    print(f"Replicas    : {replicas['min']}-{replicas['max']}")
    print(f"Image       : {application['image']}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
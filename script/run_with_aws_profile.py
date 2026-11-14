#!/usr/bin/env python3
"""Run a child process with short-lived credentials from an AWS CLI profile."""

import json
import os
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: script/run_with_aws_profile.py PROFILE COMMAND [ARG ...]", file=sys.stderr)
        return 2

    profile = sys.argv[1]
    command = sys.argv[2:]
    try:
        exported = subprocess.run(
            ["aws", "configure", "export-credentials", "--profile", profile, "--format", "process"],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as error:
        print(f"Could not export temporary AWS credentials for profile {profile}.", file=sys.stderr)
        if error.stderr:
            print(error.stderr.strip(), file=sys.stderr)
        return error.returncode
    except FileNotFoundError:
        print("AWS CLI v2 is required to publish media.", file=sys.stderr)
        return 127

    credentials = json.loads(exported.stdout)
    environment = os.environ.copy()
    environment.update(
        AWS_ACCESS_KEY_ID=credentials["AccessKeyId"],
        AWS_SECRET_ACCESS_KEY=credentials["SecretAccessKey"],
        AWS_SESSION_TOKEN=credentials["SessionToken"],
        # The console sign-in is in us-east-2; this media bucket is in us-east-1.
        AWS_REGION="us-east-1",
    )
    return subprocess.run(command, env=environment, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())

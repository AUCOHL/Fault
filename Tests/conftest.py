import os
import pytest


def pytest_configure():
    __dir__ = os.path.dirname(os.path.abspath(__file__))
    pytest.root = os.path.dirname(__dir__)

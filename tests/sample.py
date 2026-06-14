"""Sample Python file so tests/validate.sh can confirm bat shows syntax colors."""


def greet(name: str) -> str:
    """Return a friendly greeting."""
    return f"Hello, {name}!"


if __name__ == "__main__":
    for who in ("world", "terminal"):
        print(greet(who))

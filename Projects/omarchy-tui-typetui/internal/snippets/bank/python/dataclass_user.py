from dataclasses import dataclass, field
from typing import Optional


@dataclass
class User:
    username: str
    email: str
    age: Optional[int] = None
    tags: list[str] = field(default_factory=list)

    def __post_init__(self):
        if "@" not in self.email:
            raise ValueError(f"invalid email: {self.email}")
        if self.age is not None and self.age < 0:
            raise ValueError("age cannot be negative")

    def add_tag(self, tag: str) -> None:
        if tag not in self.tags:
            self.tags.append(tag)

    def to_dict(self) -> dict:
        return {
            "username": self.username,
            "email": self.email,
            "age": self.age,
            "tags": list(self.tags),
        }

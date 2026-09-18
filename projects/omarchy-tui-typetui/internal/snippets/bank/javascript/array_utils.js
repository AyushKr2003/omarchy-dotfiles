function groupBy(array, keyFn) {
  return array.reduce((groups, item) => {
    const key = keyFn(item);
    if (!groups[key]) {
      groups[key] = [];
    }
    groups[key].push(item);
    return groups;
  }, {});
}

function chunk(array, size) {
  const result = [];
  for (let i = 0; i < array.length; i += size) {
    result.push(array.slice(i, i + size));
  }
  return result;
}

function flatten(array, depth = 1) {
  return depth > 0
    ? array.reduce(
        (acc, val) =>
          acc.concat(Array.isArray(val) ? flatten(val, depth - 1) : val),
        []
      )
    : array.slice();
}

const users = [
  { name: "Alice", role: "admin" },
  { name: "Bob", role: "user" },
];
const byRole = groupBy(users, (user) => user.role);

async function promisePool(tasks, concurrency) {
  const results = new Array(tasks.length);
  let index = 0;

  async function worker() {
    while (index < tasks.length) {
      const current = index++;
      try {
        results[current] = await tasks[current]();
      } catch (error) {
        results[current] = { error };
      }
    }
  }

  const workers = Array.from({ length: concurrency }, () => worker());
  await Promise.all(workers);
  return results;
}

const urls = ["/a", "/b", "/c", "/d", "/e"];
const tasks = urls.map((url) => () => fetch(url).then((r) => r.json()));

promisePool(tasks, 3).then((results) => {
  console.log("all done:", results);
});

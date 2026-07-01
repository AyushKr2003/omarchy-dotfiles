async function fetchWithRetry(url, options = {}, maxAttempts = 4) {
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const response = await fetch(url, options);
      if (!response.ok) {
        throw new Error(`request failed with status ${response.status}`);
      }
      return await response.json();
    } catch (error) {
      lastError = error;
      if (attempt === maxAttempts) break;

      const delay = 2 ** attempt * 100;
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

async function loadUserProfile(userId) {
  const data = await fetchWithRetry(`/api/users/${userId}`);
  return {
    id: data.id,
    name: data.full_name,
    email: data.email,
  };
}

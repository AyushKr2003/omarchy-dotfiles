def paginate(items, page_size=20):
    page = []
    for item in items:
        page.append(item)
        if len(page) == page_size:
            yield page
            page = []
    if page:
        yield page


def fetch_all_pages(api_client, endpoint, page_size=50):
    cursor = None
    while True:
        response = api_client.get(
            endpoint,
            params={"cursor": cursor, "limit": page_size},
        )
        data = response.json()
        for item in data["results"]:
            yield item

        cursor = data.get("next_cursor")
        if not cursor:
            break


def chunked_sum(numbers, chunk_size=1000):
    total = 0
    for chunk in paginate(numbers, chunk_size):
        total += sum(chunk)
    return total

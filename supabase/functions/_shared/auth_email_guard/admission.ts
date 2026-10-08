export class Admission {
  #active = 0;
  #sources = new Map<string, number>();
  #items = new Set<string>();
  acquire(
    source: string,
  ): null | { bind(id: string): boolean; release(): void } {
    if (
      !/^[0-9a-f]{64}$/.test(source) || this.#active >= 64 ||
      (this.#sources.get(source) ?? 0) >= 2
    ) return null;
    this.#active++;
    this.#sources.set(source, (this.#sources.get(source) ?? 0) + 1);
    let released = false, item: string | undefined;
    return {
      bind: (id: string) => {
        if (
          released || item !== undefined ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
            .test(id) ||
          this.#items.has(id)
        ) return false;
        this.#items.add(id);
        item = id;
        return true;
      },
      release: () => {
        if (released) return;
        released = true;
        this.#active--;
        const count = (this.#sources.get(source) ?? 1) - 1;
        if (count === 0) this.#sources.delete(source);
        else this.#sources.set(source, count);
        if (item) this.#items.delete(item);
      },
    };
  }
  snapshot() {
    return { active: this.#active };
  }
}

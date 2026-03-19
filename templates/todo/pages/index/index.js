const STORAGE_KEY = 'todo_items'

Page({
  data: {
    draft: '',
    items: []
  },
  onShow() {
    this.loadItems()
  },
  onInput(e) {
    this.setData({ draft: e.detail.value })
  },
  loadItems() {
    const items = wx.getStorageSync(STORAGE_KEY) || []
    this.setData({ items })
  },
  saveItems(items) {
    wx.setStorageSync(STORAGE_KEY, items)
    this.setData({ items, draft: '' })
  },
  addItem() {
    const text = (this.data.draft || '').trim()
    if (!text) return
    const items = this.data.items.slice()
    items.unshift({ id: Date.now().toString(), text, done: false })
    this.saveItems(items)
  },
  toggleItem(e) {
    const id = e.currentTarget.dataset.id
    const items = this.data.items.map((it) =>
      it.id === id ? { ...it, done: !it.done } : it
    )
    this.saveItems(items)
  },
  removeItem(e) {
    const id = e.currentTarget.dataset.id
    const items = this.data.items.filter((it) => it.id !== id)
    this.saveItems(items)
  }
})

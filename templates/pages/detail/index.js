const STORAGE_KEY = 'notebook_notes'

Page({
  data: { id: null, title: '', content: '' },
  onLoad(options) {
    if (options.id) {
      const notes = wx.getStorageSync(STORAGE_KEY) || []
      const note = notes.find(n => n.id === options.id)
      if (note) this.setData({
        id: note.id, title: note.title, content: note.content
      })
    }
  },
  onTitleInput(e) { this.setData({ title: e.detail.value }) },
  onContentInput(e) { this.setData({ content: e.detail.value }) },
  saveNote() {
    if (!this.data.title.trim()) {
      wx.showToast({ title: '标题不能为空', icon: 'none' })
      return
    }
    const notes = wx.getStorageSync(STORAGE_KEY) || []
    const now = new Date().toLocaleString('zh-CN')
    if (this.data.id) {
      const idx = notes.findIndex(n => n.id === this.data.id)
      if (idx >= 0) notes[idx] = {
        ...notes[idx], title: this.data.title,
        content: this.data.content, updatedAt: now
      }
    } else {
      notes.unshift({
        id: Date.now().toString(), title: this.data.title,
        content: this.data.content, updatedAt: now
      })
    }
    wx.setStorageSync(STORAGE_KEY, notes)
    wx.navigateBack()
  }
})

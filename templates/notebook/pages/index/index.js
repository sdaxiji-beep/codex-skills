const STORAGE_KEY = 'notebook_notes'

Page({
  data: { notes: [] },
  onShow() { this.loadNotes() },
  loadNotes() {
    const notes = wx.getStorageSync(STORAGE_KEY) || []
    this.setData({ notes })
  },
  addNote() {
    wx.navigateTo({ url: '/pages/detail/index' })
  },
  openNote(e) {
    const id = e.currentTarget.dataset.id
    wx.navigateTo({ url: `/pages/detail/index?id=${id}` })
  },
  deleteNote(e) {
    const id = e.currentTarget.dataset.id
    const notes = this.data.notes.filter(n => n.id !== id)
    wx.setStorageSync(STORAGE_KEY, notes)
    this.setData({ notes })
  }
})

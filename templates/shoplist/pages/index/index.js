Page({
  data: {
    products: [
      { id: 'p1', name: '经典卤味拼盘', price: 39.9 },
      { id: 'p2', name: '香辣鸭脖', price: 19.9 },
      { id: 'p3', name: '招牌牛肉', price: 29.9 },
      { id: 'p4', name: '藤椒鸡爪', price: 24.9 }
    ]
  },
  buyNow(e) {
    const id = e.currentTarget.dataset.id
    wx.showToast({ title: `已选择商品 ${id}`, icon: 'none' })
  }
})

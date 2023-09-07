pub struct NFTDetails {
  pub let id: String
  init(id: String) {
    self.id = id
  }
}

pub fun main(): {String:String} {
  let nft = NFTDetails(id: "1")
  return {
    "id": nft.id
  }
}

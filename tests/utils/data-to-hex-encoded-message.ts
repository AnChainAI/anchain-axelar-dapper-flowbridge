export function dataToHexEncodedMessage(
  commandIds: string[],
  commands: string[],
  params: string[][],
): string {
  const encoder = new TextEncoder()
  let message: string = ''
  commandIds.forEach((id) => {
    message += id
  })

  commands.forEach((c) => {
    message += c
  })

  params.forEach((p) => {
    p.forEach((input) => {
      message += input
    })
  })

  return Buffer.from(encoder.encode(message)).toString('hex')
}

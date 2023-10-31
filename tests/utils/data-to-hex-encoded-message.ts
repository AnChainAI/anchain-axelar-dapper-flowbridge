export function convertInputsToUtf8(inputs: (string | string[])[]): string {
  let convertedInput: string = ''

  inputs.forEach((input) => {
    if (Array.isArray(input)) {
      convertedInput += convertInputsToUtf8(input)
    } else {
      convertedInput += input
    }
  })

  return convertedInput
}

export function dataToHexEncodedMessage(
  commandIds: string[],
  commands: string[],
  params: (string | string[])[][],
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
    message += convertInputsToUtf8(p)
  })

  return Buffer.from(encoder.encode(message)).toString('hex')
}

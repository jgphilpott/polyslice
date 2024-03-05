var device

document.addEventListener("DOMContentLoaded", event => {
    let connection = document.getElementById("connection")
    connection.addEventListener("click", async () => {
        try {

            device = await navigator.serial.requestPort()

            await device.open({baudRate: 115200})

            console.log("Opened: ", device)
            console.log("Info: ", device.getInfo())

            const encoder = new TextEncoder()
            const writer = device.writable.getWriter()

            await writer.write(encoder.encode("G28\n"))

            writer.releaseLock()

            await device.close()

        } catch (error) {

            console.log(error)

        }
    })
})
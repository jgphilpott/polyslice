let device = {}

async function connect() {

    try {

        device = await navigator.serial.requestPort()

        await device.open({baudRate: 115200})

        connected()

        read()

    } catch (error) {

        console.log("Failed to connect with serial port: " + error)

    }

}

async function disconnect() {

    try {

        await device.forget()

        disconnected()

    } catch (error) {

        console.log("Failed to disconnect with serial port: " + error)

    }

}

function connected() {

    device.connected = true

    $("button#connection").text("Disconnect")

    $("textarea#prompt").prop("disabled", false)

    $("button#connection").addClass("disconnect")
    $("button#connection").removeClass("connect")

    console.log("Connected with: ", device)

    $("textarea#prompt").focus()

}

function disconnected() {

    device.connected = false

    $("button#connection").text("Connect")

    $("textarea#prompt").prop("disabled", true)

    $("button#connection").addClass("connect")
    $("button#connection").removeClass("disconnect")

    console.log("Disconnected with: ", device)

}

async function read() {
    while (device.readable) {

        const decoder = new TextDecoder()
        const reader = device.readable.getReader()

        console.log("Started reading serial port.")

        try {

            while (true) {

                const {value, done} = await reader.read()

                let text = decoder.decode(value).replace("echo:", "")
                let time = new Date().toLocaleTimeString([], {hour12: false})

                if (text.toLowerCase().includes("unknown")) {

                    text = "<span class='error'>" + text + "</span>"

                }

                $("#output").append("<p>" + time + "<span class='pointer'> >>> </span>" + text + "</p>")

                let output = document.getElementById("output")
                output.scrollTop = output.scrollHeight

                if (done) break

            }

        } catch (error) {

            console.log("Stopped reading serial port.")

        } finally {

            reader.releaseLock()

            break

        }

    }
}

async function write(text) {

    const encoder = new TextEncoder()
    const writer = device.writable.getWriter()

    await writer.write(encoder.encode(text))

    writer.releaseLock()

}

document.addEventListener("DOMContentLoaded", (event) => {

    if (navigator.serial) {

        $("#compatible").css("display", "block")

        let connection = $("button#connection")
        let prompt = $("textarea#prompt")

        navigator.serial.addEventListener("connect", (event) => {
            connected()
        })

        navigator.serial.addEventListener("disconnect", (event) => {
            disconnected()
        })

        prompt.on("keydown", async (event) => {

            if (event.key == "Enter" && !event.shiftKey) {

                event.preventDefault()

                let text = $(event.target).val() + "\n"
                let time = new Date().toLocaleTimeString([], {hour12: false})

                $("#input").append("<p>" + time + "<span class='pointer'> >>> </span>" + text + "</p>")

                let input = document.getElementById("input")
                input.scrollTop = input.scrollHeight

                $(event.target).val("").change()
                $(event.target).attr("rows", 1)

                write(text)

            } else if (event.key == "Enter" && event.shiftKey) {

                rows = Number($(event.target).attr("rows"))

                $(event.target).attr("rows", rows + 1)

            }

        })

        connection.on("click", async () => {
            if (device.connected) {
                disconnect()
            } else {
                connect()
            }
        })

    } else {

        $("#incompatible").css("display", "block")

    }

})

window.onbeforeunload = (event) => {
    disconnect()
}
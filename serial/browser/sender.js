let device = {}

async function connect() {

    try {

        device = await navigator.serial.requestPort()

        let baudRate = Number($("#baud-rate").val())
        let bufferSize = Number($("#buffer-size").val())
        let dataBits = Number($("#data-bits").val())
        let stopBits = Number($("#stop-bits").val())
        let flowControl = String($("#flow-control").val())
        let parity = String($("#parity").val())

        await device.open({
            baudRate: baudRate,
            bufferSize: bufferSize,
            dataBits: dataBits,
            stopBits: stopBits,
            flowControl: flowControl,
            parity: parity
        })

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

    let time = "<span class='time'>" + new Date().toLocaleTimeString([], {hour12: false}) + "</span>"
    $("#output").append("<p>" + time + "<span class='pointer'> >>> </span>Connected</p>")

    console.log("Connected with: ", device)

    $("textarea#prompt").focus()

}

function disconnected() {

    device.connected = false

    $("button#connection").text("Connect")

    $("textarea#prompt").prop("disabled", true)

    $("button#connection").addClass("connect")
    $("button#connection").removeClass("disconnect")

    let time = "<span class='time'>" + new Date().toLocaleTimeString([], {hour12: false}) + "</span>"
    $("#output").append("<p>" + time + "<span class='pointer'> >>> </span>Disconnected</p>")

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
                let time = "<span class='time'>" + new Date().toLocaleTimeString([], {hour12: false}) + "</span>"

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

        navigator.serial.addEventListener("connect", (event) => {
            connected()
        })

        navigator.serial.addEventListener("disconnect", (event) => {
            disconnected()
        })

        $("button#connection").on("click", async (event) => {
            if (device.connected) {
                disconnect()
            } else {
                connect()
            }
        })

        $("div#settings .control").on("change", async (event) => {

            if (device.connected) disconnect()

            let setting = $(event.target).attr("name")
            let time = "<span class='time'>" + new Date().toLocaleTimeString([], {hour12: false}) + "</span>"

            $("#output").append("<p>" + time + "<span class='pointer'> >>> </span>Connection Setting Changed: <b>" + setting + "</b></p>")

        })

        $("textarea#prompt").on("keydown", async (event) => {

            if (event.key == "Enter" && !event.shiftKey) {

                event.preventDefault()

                let text = $(event.target).val() + "\n"
                let time = "<span class='time'>" + new Date().toLocaleTimeString([], {hour12: false}) + "</span>"

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

    } else {

        $("#incompatible").css("display", "block")

    }

})

window.onbeforeunload = (event) => {
    disconnect()
}
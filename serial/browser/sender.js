let device = {}
let history = []

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

        console.log("Failed to connect with serial port: ", error)

    }

}

async function disconnect() {

    try {

        await device.forget()

        disconnected()

    } catch (error) {

        console.log("Failed to disconnect with serial port: ", error)

    }

}

function connected() {

    device.connected = true

    $("button#connection").text("Disconnect")

    $("textarea#prompt").prop("disabled", false)

    $("button#connection").addClass("disconnect")
    $("button#connection").removeClass("connect")

    log("output", "<span class='success'>Connected</span>")

    console.log("Connected with: ", device)

    $("textarea#prompt").focus()

}

function disconnected() {

    device.connected = false

    $("button#connection").text("Connect")

    $("textarea#prompt").prop("disabled", true)

    $("button#connection").addClass("connect")
    $("button#connection").removeClass("disconnect")

    log("output", "<span class='error'>Disconnected</span>")

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

                let text = decoder.decode(value).replace("echo:", "").replace("\n", " ")

                text = text.replace("Unknown command:", "<span class='error'>Unknown command:</span>")
                text = text.replace("busy:", "<span class='info'>Busy:</span>")
                text = text.replace("ok", "<span class='success'>OK</span>")

                text = text.replace("X:", "<b class='x'>X:</b> ")
                text = text.replace("Y:", "<b class='y'>Y:</b> ")
                text = text.replace("Z:", "<b class='z'>Z:</b> ")
                text = text.replace("E:", "<b class='e'>E:</b> ")

                log("output", text)

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

function log(zone, text) {

    let time = "<span class='time'>" + new Date().toLocaleTimeString([], {hour12: false}) + "</span>"

    $("#" + zone + "").append("<p>" + time + "<span class='pointer'> >>> </span>" + text + "</p>")

    zone = document.getElementById(zone)

    zone.scrollTop = zone.scrollHeight

}

document.addEventListener("DOMContentLoaded", (event) => {

    if (navigator.serial) {

        let commandIndex = 0

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

            log("output", "<span class='info'>Connection Setting Changed:</span> " + setting + "")

        })

        $("textarea#prompt").on("keydown", async (event) => {

            let prompt = $(event.target).val()

            if (event.key == "Enter" && !event.shiftKey) {

                commandIndex = 0

                event.preventDefault()

                if (prompt.length) {

                    history.unshift(prompt)

                    let text = prompt + "\n"

                    $(event.target).val("").change()
                    $(event.target).attr("rows", 1)

                    text.split("\n").forEach((command) => {

                        if (command.length) log("input", command)

                    })

                    write(text)

                }

            } else if (event.key == "Enter" && event.shiftKey) {

                let rows = Number($(event.target).attr("rows"))

                $(event.target).attr("rows", rows + 1)

            } else if ((event.key == "ArrowUp" || event.key == "ArrowDown") && history.length) {

                let cursor = Number($(event.target).prop("selectionStart"))
                let size = Number($(event.target).val().length)

                if (event.key == "ArrowUp" && cursor == 0) {

                    commandIndex += 1

                    if (commandIndex > history.length) commandIndex = history.length

                    $(event.target).attr("rows", history[commandIndex - 1].split("\n").length)
                    $(event.target).val(history[commandIndex - 1])

                }

                if (event.key == "ArrowDown" && cursor == size) {

                    commandIndex -= 1

                    if (commandIndex < 0) commandIndex = 0

                    if (commandIndex) {

                        $(event.target).attr("rows", history[commandIndex - 1].split("\n").length)
                        $(event.target).val(history[commandIndex - 1])

                    } else {

                        $(event.target).val("").change()
                        $(event.target).attr("rows", 1)

                    }

                }

            }

        })

    } else {

        $("#incompatible").css("display", "block")

    }

})

window.onbeforeunload = (event) => {

    disconnect()

}
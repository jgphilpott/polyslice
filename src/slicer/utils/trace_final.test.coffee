describe 'trace inset path at Z11.9', ->

    it 'should trace junction', ->

        paths = require './paths'

        outerWall = [
            {x: 104.413, y: 120.172, z: 11.9}
            {x: 104.329, y: 120.176, z: 11.9}
            {x: 104.262, y: 120.179, z: 11.9}
            {x: 104.251, y: 120.179, z: 11.9}
            {x: 104.184, y: 120.179, z: 11.9}
            {x: 104.12, y: 120.18, z: 11.9}
            {x: 104.059, y: 120.18, z: 11.9}
            {x: 104.2, y: 120.18, z: 11.9}
            {x: 104.2, y: 121.0, z: 11.9}
            {x: 105.0, y: 121.0, z: 11.9}
            {x: 105.0, y: 120.18, z: 11.9}
        ]

        result = paths.createInsetPath outerWall, 0.4, false
        console.log "Inner wall result (#{result.length} vertices):"
        for p in result
            console.log "  X=#{p.x.toFixed(4)} Y=#{p.y.toFixed(4)}"

        spikes = result.filter (p) -> p.x < 105 and p.y < 120.0
        console.log "Spike vertices (near junction, Y<120): #{spikes.length}"
        for p in spikes
            console.log "  SPIKE: X=#{p.x.toFixed(4)} Y=#{p.y.toFixed(4)}"

        expect(result.length).toBeGreaterThan(0)


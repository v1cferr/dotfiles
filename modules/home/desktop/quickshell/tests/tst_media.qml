// MediaMath: which MPRIS player the shell shows and drives when several are on the bus.
import QtQuick
import QtTest
import "../media"

TestCase {
    name: "Media"

    MediaMath {
        id: m
    }
    function p(key, playing) {
        return {
            key: key,
            playing: !!playing
        };
    }

    function test_no_player_is_no_pick() {
        compare(m.pick([], {}), "");
        compare(m.pick(null, {}), "");
    }
    function test_playing_beats_a_paused_player_seen_later() {
        const seen = {
            spotifast: 200,
            pear: 100
        };
        compare(m.pick([p("spotifast"), p("pear", true)], seen), "pear", "a paused Spotifast no longer wins");
    }
    function test_two_playing_the_newest_start_wins() {
        compare(m.pick([p("a", true), p("b", true)], {
            a: 100,
            b: 300
        }), "b");
    }
    function test_a_pause_keeps_the_player() {
        // A plays, B paused before it; A pauses between tracks: nobody else started, so A stays.
        let seen = m.stamp({}, "b", 100);
        seen = m.stamp(seen, "a", 200);
        compare(m.pick([p("a"), p("b")], seen), "a");
    }
    function test_the_last_one_playing_beats_one_never_played() {
        compare(m.pick([p("a"), p("z")], {
            z: 50
        }), "z");
    }
    function test_closing_the_current_falls_to_the_next() {
        let seen = m.stamp(m.stamp({}, "b", 100), "a", 200);
        seen = m.prune(seen, ["b"]);
        compare(Object.keys(seen).join(","), "b", "the closed player's stamp is gone");
        compare(m.pick([p("b")], seen), "b");
    }
    function test_with_no_history_the_key_decides_not_the_bus_order() {
        compare(m.pick([p("org.mpris.MediaPlayer2.vlc"), p("org.mpris.MediaPlayer2.YoutubeMusic")], {}), "org.mpris.MediaPlayer2.YoutubeMusic");
        compare(m.pick([p("org.mpris.MediaPlayer2.YoutubeMusic"), p("org.mpris.MediaPlayer2.vlc")], {}), "org.mpris.MediaPlayer2.YoutubeMusic");
    }
    function test_stamp_does_not_mutate() {
        const seen = {
            a: 1
        };
        m.stamp(seen, "a", 9);
        compare(seen.a, 1);
    }
}

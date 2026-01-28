//
//  Stream+keyDiffStream.swift
//  QStream
//
//  Created by Quirin Schweigert on 16.04.25.
//

extension Stream {
    public func keyDiffStream<K, T>() async
    -> some Stream<(removals: [K : T], insertions: [K : T])> where V == Dictionary<K, T> {
        await selfScan { a, b in
            (a?.filter { !b.keys.contains($0.key) } ?? [:], b.filter { !(a?.keys.contains($0.key) ?? false) })
        }
    }
}

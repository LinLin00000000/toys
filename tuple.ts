const makeTuple = <T1, T2>(a: T1, b: T2) => ({
    fst: () => a,
    snd: () => b,
})

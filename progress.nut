class ProgressReport {
    _total_work = 0;
    _percent = 10;
    _progress = 0;
    _milestone = 0;

    constructor(total_work, pct = 10) {
        this.Reset(total_work, pct);
    }

    function Increment() {
        if (this._progress >= this._total_work)
            return false;
        ++this._progress;
        if (100 * this._progress >= this._milestone * this._total_work) {
            this._milestone += this._percent;
            return true;
        }
        return false;
    }

    function GetProgress() {
        return this._progress;
    }

    function GetProgressPct() {
        return (100 * this._progress) / this._total_work;
    }

    function _tostring() {
        return GetProgressPct() + "% [" + this._progress + "/" + this._total_work + "]";
    }

    function Reset(total_work, pct = null) {
        try {
            assert(total_work > 0);
            if (pct != null) {
                assert(pct > 0 && pct < 100);
                this._percent = pct;
            }
            this._total_work = total_work;
            this._progress = 0;
            this._milestone = this._percent;
        } catch(exception) {
        }
    }
}

/******************************************************************************
 * Copyright (C) 2017 Yukai Miao <tjumyk@gmail.com>                           *
 *                                                                            *
 * This program is free software; you can redistribute it and/or modify       *
 * it under the terms of the GNU General Public License as published by       *
 * the Free Software Foundation; either version 3 of the License, or          *
 * (at your option) any later version.                                        *
 *                                                                            *
 * This program is distributed in the hope that it will be useful,            *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
 * GNU General Public License for more details.                               *
 *                                                                            *
 * You should have received a copy of the GNU General Public License along    *
 * with this program; if not, write to the Free Software Foundation, Inc.,    *
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.                *
 ******************************************************************************/

public class GpuProvider : Provider {
    public GpuProvider() {
        base("gpu", {"util", "memtotal", "memused", "memfree"}, "p");
    }

    public override void update() {
	    try {
            string[] spawn_args = {"nvidia-smi", "-i", "0", "--query-gpu=utilization.gpu,memory.total,memory.used,memory.free", "--format=csv,noheader,nounits"};
            string spawn_stdout;
            string spawn_stderr;
            int spawn_status;
            Process.spawn_sync(null, spawn_args, null, SpawnFlags.SEARCH_PATH, null, out spawn_stdout, out spawn_stderr, out spawn_status);
            string[] columns = spawn_stdout.split(", ");
            this.values[0] = double.parse(columns[0]) / 100.0;
            for(int i = 1 ; i < 4; ++i)
                this.values[i] = double.parse(columns[i]) * 1000000;
        } catch (SpawnError e) {
            stdout.printf ("Error: %s\n", e.message);
        }
    }
}

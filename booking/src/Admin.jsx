import { useEffect, useState } from 'react'

const STORAGE_KEY = 'booking.admin.bookings'

const emptyForm = {
  name: '',
  date: '',
  time: '',
  guests: '2',
  notes: '',
}

function loadBookings() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : []
  } catch {
    return []
  }
}

function Admin() {
  const [form, setForm] = useState(emptyForm)
  const [bookings, setBookings] = useState(loadBookings)
  const [error, setError] = useState('')

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(bookings))
  }, [bookings])

  const updateField = (field) => (event) => {
    setForm((prev) => ({ ...prev, [field]: event.target.value }))
  }

  const handleSubmit = (event) => {
    event.preventDefault()

    if (!form.name.trim() || !form.date || !form.time) {
      setError('Name, date and time are required.')
      return
    }

    const booking = {
      id: crypto.randomUUID(),
      name: form.name.trim(),
      date: form.date,
      time: form.time,
      guests: Number(form.guests) || 1,
      notes: form.notes.trim(),
    }

    setBookings((prev) =>
      [...prev, booking].sort((a, b) =>
        `${a.date}T${a.time}`.localeCompare(`${b.date}T${b.time}`),
      ),
    )
    setForm(emptyForm)
    setError('')
  }

  const removeBooking = (id) => {
    setBookings((prev) => prev.filter((booking) => booking.id !== id))
  }

  return (
    <main className="page admin">
      <h1>Booking Admin</h1>

      <form className="admin-form" onSubmit={handleSubmit}>
        <label className="field">
          <span>Name</span>
          <input
            type="text"
            value={form.name}
            onChange={updateField('name')}
            placeholder="Guest name"
          />
        </label>

        <div className="field-row">
          <label className="field">
            <span>Date</span>
            <input type="date" value={form.date} onChange={updateField('date')} />
          </label>

          <label className="field">
            <span>Time</span>
            <input type="time" value={form.time} onChange={updateField('time')} />
          </label>

          <label className="field field-guests">
            <span>Guests</span>
            <input
              type="number"
              min="1"
              value={form.guests}
              onChange={updateField('guests')}
            />
          </label>
        </div>

        <label className="field">
          <span>Notes</span>
          <textarea
            rows="2"
            value={form.notes}
            onChange={updateField('notes')}
            placeholder="Optional notes"
          />
        </label>

        {error && <p className="form-error">{error}</p>}

        <button type="submit" className="btn-primary">
          Add booking
        </button>
      </form>

      <section className="bookings">
        <h2>
          Bookings <span className="count">({bookings.length})</span>
        </h2>

        {bookings.length === 0 ? (
          <p className="empty">No bookings yet.</p>
        ) : (
          <ul className="booking-list">
            {bookings.map((booking) => (
              <li key={booking.id} className="booking-item">
                <div className="booking-main">
                  <strong>{booking.name}</strong>
                  <span className="booking-when">
                    {booking.date} at {booking.time} &middot; {booking.guests}{' '}
                    {booking.guests === 1 ? 'guest' : 'guests'}
                  </span>
                  {booking.notes && (
                    <span className="booking-notes">{booking.notes}</span>
                  )}
                </div>
                <button
                  type="button"
                  className="btn-remove"
                  onClick={() => removeBooking(booking.id)}
                  aria-label={`Remove booking for ${booking.name}`}
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  )
}

export default Admin

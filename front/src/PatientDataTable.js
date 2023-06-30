import React, { useState } from 'react';
import { useTable, useSortBy } from 'react-table';
import axios from 'axios';

function PatientDataTable({ data }) {
    const [patientData, setPatientData] = useState(null);

    const fetchPatientData = (dni) => {
        axios.get(`/api/get_patient_data/${dni}`)
            .then(response => setPatientData(response.data))
            .catch(error => console.error('Error:', error));
    };

    const closeAppointment = (id) => {
        if (window.confirm("¿Estás seguro de que quieres cerrar esta cita?")) {
            axios.post('/api/close_appointment', { id: id })
                .then(response => {
                    if (response.data.status === 'success') {
                        alert("Cita cerrada con éxito!");
                        window.location.reload(false);
                    } else {
                        alert("Error cerrando la cita: " + response.data.error);
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    alert("Error cerrando la cita: " + error.message);
                });
        }
    };

    const columns = React.useMemo(
        () => [
            {
                Header: 'DNI',
                accessor: 'dni',
                Cell: ({ value }) => (
                    <div onMouseOver={() => fetchPatientData(value)}>
                        {value}
                        {patientData && patientData.dni === value && (
                            <div className="tooltip">
                                <p>Nombre: {patientData.name}</p>
                                <p>Apellidos: {patientData.surnames}</p>
                                <p>Teléfono: {patientData.phone}</p>
                            </div>
                        )}
                    </div>
                ),
            },
            {
                Header: 'Diagnosis',
                accessor: 'diagnosis',
            },
            {
                Header: 'Severity',
                accessor: 'severity',
            },
            {
                Header: 'Appointment',
                accessor: 'appointment',
                Cell: ({ value }) => value ? "✔️" : "",
            },
            {
                Header: 'Acción',
                id: 'action',
                Cell: ({ row }) => {
                    return row.original.appointment ? (
                        <button onClick={() => closeAppointment(row.original.id)}>
                            Cerrar cita
                        </button>
                    ) : null;
                },
            },
        ],
        []
    );

    const {
        getTableProps,
        getTableBodyProps,
        headerGroups,
        rows,
        prepareRow,
    } = useTable({ columns, data }, useSortBy);

    return (
        <table {...getTableProps()} style={{ width: "100%" }}>
            <thead>
                {headerGroups.map(headerGroup => (
                    <tr {...headerGroup.getHeaderGroupProps()}>
                        {headerGroup.headers.map(column => (
                            <th {...column.getHeaderProps(column.getSortByToggleProps())}>
                                {column.render('Header')}
                                <span>
                                    {column.isSorted
                                        ? column.isSortedDesc
                                            ? ' 🔽'
                                            : ' 🔼'
                                        : ''}
                                </span>
                            </th>
                        ))}
                    </tr>
                ))}
            </thead>
            <tbody {...getTableBodyProps()}>
                {rows.map(row => {
                    prepareRow(row);
                    return (
                        <tr {...row.getRowProps()}>
                            {row.cells.map(cell => (
                                <td {...cell.getCellProps()}>{cell.render('Cell')}</td>
                            ))}
                        </tr>
                    );
                })}
            </tbody>
        </table>
    );
}

export default PatientDataTable;
